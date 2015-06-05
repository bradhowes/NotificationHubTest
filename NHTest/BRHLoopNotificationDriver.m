// BRHLoopNotificationDriver.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHAPNsClient.h"
#import "BRHEventLog.h"
#import "BRHLatencySample.h"
#import "BRHLogger.h"
#import "BRHLoopNotificationDriver.h"
#import "BRHUserSettings.h"

static const NSTimeInterval BRHLoopNotificationDriverOutstandingTimeToLive = 120.0;

static OSStatus
extractIdentityAndTrust(CFDataRef inPKCS12Data, SecIdentityRef* outIdentity, SecTrustRef* outTrust, CFStringRef keyPassword)
{
    OSStatus securityError = errSecSuccess;
    
    const void* keys[] = { kSecImportExportPassphrase };
    const void* values[] = { keyPassword };
    CFDictionaryRef optionsDictionary = CFDictionaryCreate(NULL, keys, values, (keyPassword ? 1 : 0), NULL, NULL);
    
    CFArrayRef items = NULL;
    securityError = SecPKCS12Import(inPKCS12Data, optionsDictionary, &items);
    
    if (securityError == 0) {
        CFDictionaryRef myIdentityAndTrust = CFArrayGetValueAtIndex (items, 0);
        const void* tempIdentity = CFDictionaryGetValue(myIdentityAndTrust, kSecImportItemIdentity);
        CFRetain(tempIdentity);
        *outIdentity = (SecIdentityRef)tempIdentity;
        const void* tempTrust = CFDictionaryGetValue (myIdentityAndTrust, kSecImportItemTrust);
        CFRetain(tempTrust);
        *outTrust = (SecTrustRef)tempTrust;
    }
    
    if (optionsDictionary) CFRelease(optionsDictionary);
    if (items) CFRelease(items);
    
    return securityError;
}

@interface BRHLoopNotificationDriver () <BRHAPNsClientDelegate>

@property (strong, nonatomic) BRHAPNsClient *apns;
@property (assign, nonatomic) SecIdentityRef identity;
@property (assign, nonatomic) NSUInteger notificationSequenceId;
@property (strong, nonatomic) NSMutableDictionary *outstandingNotifications;
@property (strong, nonatomic) NSTimer *emitter;

- (BOOL)connect;
- (void)startEmitter;
- (void)stopEmitter;
- (BRHLatencySample *)findOutstandingNotification:(NSNumber *)identifier;

/*!
 * @brief Send out a push notification from the device to itself
 */
- (void)emitNotification;
- (void)emitterFired:(NSTimer *)timer;

@end

@implementation BRHLoopNotificationDriver

- (instancetype)init
{
    self = [super init];
    if (self) {
        _notificationSequenceId = 0;
        _outstandingNotifications = [NSMutableDictionary dictionaryWithCapacity:10];
        _emitter = nil;
        _apns = nil;
    }

    return self;
}

- (void)alertCertNotFound:(NSString *)fileName
{
    NSString *text = [NSString stringWithFormat:@"Unable to find certificate %@ to use for APNs communications. Check the filename value in Settings.", fileName];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Missing APN Certificate" message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {}]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)alertInvalidCert
{
    NSString *text = [NSString stringWithFormat:@"Unable to load certificate to use for APNs communications. Check the filename and password values in Settings."];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid APN Certificate" message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {}]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (BOOL)connect
{
    BRHUserSettings *settings = [BRHUserSettings userSettings];
    NSString *fileName = settings.useAPNsSandbox ? settings.apnsDevCertFileName : settings.apnsProdCertFileName;
    NSData *cert = [NSData dataWithContentsOfURL:[[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:fileName]];
    if (! cert) {
        [self alertCertNotFound:fileName];
        return NO;
    }

    NSString *password = settings.useAPNsSandbox ? settings.apnsDevCertPassword : settings.apnsProdCertPassword;
    if (password.length == 0)
        password = nil;

    SecTrustRef trust;
    OSStatus status = extractIdentityAndTrust((__bridge CFDataRef)cert, &_identity, &trust, (__bridge CFStringRef)password);
    password = nil;
    
    self.apns = nil;
    if (status != errSecSuccess) {
        [self alertInvalidCert];
        return NO;
    }

    DDLogInfo(@"loaded cert %@", fileName);
    [BRHLogger add:@"loaded cert for sending notifications"];
    self.apns = [[BRHAPNsClient alloc] initWithIdentity:self.identity deviceToken:self.deviceToken sandbox:settings.useAPNsSandbox];
    self.apns.delegate = self;

    return YES;
}

#pragma mark - BRHNotificationDriver Overrides

- (BOOL)startEmitting:(NSNumber *)emitInterval
{
    [super startEmitting:emitInterval];
    [self.outstandingNotifications removeAllObjects];
    if (! [self connect]) return NO;
    [self startEmitter];
    return YES;
}

- (void)stopEmitting
{
    [super stopEmitting];
    [self stopEmitter];
}

- (BRHLatencySample *)receivedNotification:(NSDictionary *)notification at:(NSDate *)when fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSNumber *identifier = notification[@"id"];
    BRHLatencySample *outstanding = [self findOutstandingNotification:identifier];
    if (! outstanding) {
        [BRHLogger add:@"Missing outstanding entry for %@", notification[@"id"]];
        return nil;
    }

    // Update the 'when' value of the incoming payload to reflect the time when the notification was really emitted.
    //
    NSMutableDictionary *patched = [NSMutableDictionary dictionaryWithDictionary:notification];
    patched[@"when"] = [NSNumber numberWithDouble:outstanding.emissionTime.timeIntervalSince1970];

    return [super receivedNotification:patched at:when fetchCompletionHandler:completionHandler];
}

#pragma mark - Notification Emission

- (void)startEmitter
{
    if (self.emitter == nil) {
        NSTimeInterval when = 1.0;
        self.emitter = [NSTimer scheduledTimerWithTimeInterval:when target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];
    }
}

- (void)stopEmitter
{
    if (self.emitter != nil) {
        [self.emitter invalidate];
        self.emitter = nil;
    }
}

- (BRHLatencySample *)findOutstandingNotification:(NSNumber *)identifier
{
    NSDate *now = [NSDate date];
    __block BRHLatencySample *found = nil;
    
    // Iterate over a copy of the outstanding notifications container so that we can remove items from the original.
    // Remove the found entry as well as any that have expired.
    //
    [[self.outstandingNotifications copy] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        BRHLatencySample *sample = obj;
        if ([sample.identifier compare:identifier] == NSOrderedSame) {
            found = sample;
            [self.outstandingNotifications removeObjectForKey:key];
        }
        else if ([now compare:sample.arrivalTime] != NSOrderedAscending) {
            [self.outstandingNotifications removeObjectForKey:key];
            [BRHEventLog add:@"expiredNotification", sample.identifier, sample.emissionTime, nil];
        }
    }];
    
    return found;
}

- (void)emitterFired:(NSTimer *)timer
{
    [self emitNotification];
    NSTimeInterval emitInterval = self.emitInterval.intValue;
    self.emitter = [NSTimer scheduledTimerWithTimeInterval:emitInterval target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];
}

- (void)emitNotification
{
    NSUInteger identifier = self.notificationSequenceId++;
    NSTimeInterval emissionTime = [[NSDate date] timeIntervalSince1970];
    NSString *identifierString = [NSString stringWithFormat:@"%lu", (unsigned long)identifier];
    NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"Testing\"},\"id\":%@,\"when\":%f}", identifierString, emissionTime];
    [BRHLogger add:@"sending notification %@", identifierString];
    [self.apns pushPayload:payload identifier:identifier];
}

#pragma mark - BRHAPNsClient Delegate Methods

- (void)sentNotification:(NSInteger)identifier
{
    BRHLatencySample *sample = [BRHLatencySample new];
    sample.emissionTime = [NSDate date];
    sample.identifier = @(identifier);
    sample.arrivalTime = [sample.emissionTime dateByAddingTimeInterval:BRHLoopNotificationDriverOutstandingTimeToLive];
    [self.outstandingNotifications setObject:sample forKey:sample.identifier];

    [BRHLogger add:@"sent notification ID %@", sample.identifier];
}

@end
