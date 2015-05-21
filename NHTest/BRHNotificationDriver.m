//
//  BRHNotificationDriver.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//
#import <math.h>
#import <Security/Security.h>

#import "BRHAPNsClient.h"
#import "BRHRemoteDriver.h"
#import "BRHEventLog.h"
#import "BRHLogger.h"
#import "BRHHistogram.h"
#import "BRHLatencyValue.h"
#import "BRHNotificationDriver.h"
#import "BRHOutstandingNotification.h"

NSString *BRHNotificationDriverReceivedNotification = @"BRHNotificationDriverReceivedNotification";
NSString *BRHNotificationDriverRunningStateChanged = @"BRHNotificationDriverRunningStateChanged";

@interface BRHNotificationDriver () <BRHAPNsClientDelegate>

@property (nonatomic, strong) BRHAPNsClient *apns;
@property (nonatomic, assign) SecIdentityRef identity;
@property (nonatomic, assign) NSUInteger notificationSequenceId;
@property (nonatomic, strong) NSMutableDictionary *outstandingNotifications;
@property (nonatomic, strong) NSTimer *emitter;
@property (nonatomic, strong) NSMutableArray *orderedLatencies;
@property (nonatomic, assign) NSTimeInterval whenOffset;
@property (nonatomic, assign) BOOL useRemoteServer;

- (void)settingsChanged:(NSNotification *)notification;
- (void)connect;
- (void)startEmitter;
- (void)stopEmitter;
- (void)emitterFired:(NSTimer *)timer;
- (void)recordLatency:(NSTimeInterval)latency forID:(NSNumber*)identifier withTime:(NSTimeInterval)when;
- (void)sentNotification:(NSInteger)identifier;

@end

@implementation BRHNotificationDriver

static OSStatus
extractIdentityAndTrust(CFDataRef inPKCS12Data, SecIdentityRef *outIdentity, SecTrustRef *outTrust, CFStringRef keyPassword)
{
    OSStatus securityError = errSecSuccess;
    
    const void *keys[] = { kSecImportExportPassphrase };
    const void *values[] = { keyPassword };
    CFDictionaryRef optionsDictionary = CFDictionaryCreate(NULL, keys, values, (keyPassword ? 1 : 0), NULL, NULL);

    CFArrayRef items = NULL;
    securityError = SecPKCS12Import(inPKCS12Data, optionsDictionary, &items);
    
    if (securityError == 0) {
        CFDictionaryRef myIdentityAndTrust = CFArrayGetValueAtIndex (items, 0);
        const void *tempIdentity = CFDictionaryGetValue(myIdentityAndTrust, kSecImportItemIdentity);
        CFRetain(tempIdentity);
        *outIdentity = (SecIdentityRef)tempIdentity;
        const void *tempTrust = CFDictionaryGetValue (myIdentityAndTrust, kSecImportItemTrust);
        CFRetain(tempTrust);
        *outTrust = (SecTrustRef)tempTrust;
    }
    
    if (optionsDictionary) CFRelease(optionsDictionary);
    if (items) CFRelease(items);
    
    return securityError;
}

- (id)init
{
    self = [super init];
    if (self) {
        _sim = NO;
        _running = NO;
        _notificationSequenceId = 0;
        _emitInterval = 60.0;
        _latencies = [NSMutableArray arrayWithCapacity:10000];
        _outstandingNotifications = [NSMutableDictionary dictionaryWithCapacity:10];
        _orderedLatencies = [NSMutableArray arrayWithCapacity:10000];
        _emitter = nil;
        _apns = nil;

        NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
        NSUInteger numBins = [settings integerForKey:@"maxBin"];
        if (numBins < 10 || numBins > 120) {
            numBins = 60;
            [settings setInteger:numBins forKey:@"maxBin"];
        }

        NSUInteger emitInterval = [settings integerForKey:@"emitInterval"];
        if (emitInterval < 10) {
            emitInterval = 10;
            [settings setInteger:numBins forKey:@"emitInterval"];
        }
        
        _sim = [settings boolForKey:@"sim"];
        _useRemoteServer = [settings boolForKey:@"useRemoteServer"];
        _bins = [BRHHistogram histogramWithSize:numBins + 1];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    }

    return self;
}

- (void)settingsChanged:(NSNotification *)notification
{
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];

    NSUInteger numBins = [settings integerForKey:@"maxBin"];
    if (numBins < 10 || numBins > 120) {
        numBins = 60;
        [settings setInteger:numBins forKey:@"maxBin"];
    }

    numBins += 1;
    if (self.bins && numBins != self.bins.count) {
        self.bins = [BRHHistogram histogramWithSize:numBins + 1];
    }

    NSUInteger emitInterval = [settings integerForKey:@"emitInterval"];
    if (emitInterval < 1) {
        emitInterval = 1;
        [settings setInteger:emitInterval forKey:@"emitInteval"];
    }

    self.useRemoteServer = [settings boolForKey:@"useRemoteServer"];
    self.sim = [settings boolForKey:@"sim"];
    if (self.sim)
        self.useRemoteServer = NO;

    [self connect];
}

- (void)editingSettings:(BOOL)state
{
    if (state) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    }
    else {
        [self settingsChanged:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    }
}

- (void)connect
{
    if (self.useRemoteServer || self.sim) return;
    
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    
    BOOL useSandbox = [settings boolForKey:@"useSandbox"];
    DDLogDebug(@"useSandbox: %d", useSandbox);
    
    NSString *fileName = [settings stringForKey:(useSandbox ? @"sandboxCertFileName" : @"prodCertFileName")];
    DDLogDebug(@"cert filename: %@", fileName);
    
    NSData *cert = [NSData dataWithContentsOfURL:[[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:fileName]];
    DDLogDebug(@"cert: %@", [cert description]);
    
    NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:(useSandbox ? @"sandboxCertPassword" : @"prodCertPassword")];
    if (password.length == 0)
        password = nil;
    
    SecTrustRef trust;
    OSStatus status = extractIdentityAndTrust((__bridge CFDataRef)cert, &_identity, &trust, (__bridge CFStringRef)password);
    password = nil;
    
    self.apns = nil;
    if (status != errSecSuccess) {
        DDLogError(@"failed to extract identity from cert - %d", (int)status);
        [BRHLogger add:@"invalid cert for sending notifications"];
        [[[UIAlertView alloc] initWithTitle:@"Invalid Certificate"
                                    message:@"Unable to load the certificate to use for APNs communications. Check the filename and password values in Settings."
                                   delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
        _running = NO;
    }
    else {
        DDLogInfo(@"loaded cert %@", fileName);
        [BRHLogger add:@"loaded cert for sending notifications"];
        self.apns = [[BRHAPNsClient alloc] initWithIdentity:self.identity
                                                      token:self.deviceToken
                                                    sandbox:useSandbox];
        self.apns.delegate = self;
    }
}

- (void)reset
{
    [self.latencies removeAllObjects];
    [self.orderedLatencies removeAllObjects];
    [self.outstandingNotifications removeAllObjects];
    [self.bins clear];
    self.whenOffset = -1.0;
}

- (void)start
{
    [BRHLogger add:@"driver starting"];

    [self reset];

    self.notificationSequenceId = 0;
    self.startTime = [NSDate date];
    _running = YES;

    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSLog(@"settings: %@", settings);

    if (self.useRemoteServer) {
        NSString *deviceToken = [self.deviceToken base64EncodedStringWithOptions:0];
        NSString *host = [settings stringForKey:@"remoteServerName"];
        long port = [settings integerForKey:@"remoteServerPort"];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld", host, port]];
        [BRHLogger add:@"remote URL: %@", url.absoluteString];
        self.remoteDriver = [[BRHRemoteDriver alloc] initWithURL:url deviceToken:deviceToken];
        [self.remoteDriver postRegistration];
    }
    else {
        if (self.sim) {
            self.apns = nil;
            self.emitInterval = 1;
        }
        else {
            [self connect];
            double value = [[[NSUserDefaults standardUserDefaults] stringForKey:@"emitInterval"] doubleValue];
            self.emitInterval = value;
        }

        [BRHLogger add:@"emit interval: %f", self.emitInterval];
        [self startEmitter];
    }
}

- (void)stop
{
    [BRHLogger add:@"driver stopping"];
    if (_running) {
        _running = NO;
        [self.outstandingNotifications removeAllObjects];
        if (self.useRemoteServer) {
            [self.remoteDriver deleteRegistration];
        }
        else {
            [self stopEmitter];
        }
    }
}

- (BRHLatencyValue *)min
{
    return [self.orderedLatencies firstObject];
}

- (BRHLatencyValue *)max
{
    return [self.orderedLatencies lastObject];
}

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

- (void)emitNotification
{
    if (self.apns != nil) {
        NSString *ident = [NSString stringWithFormat:@"%ld", (long)self.notificationSequenceId];
        NSString *payload = [NSString stringWithFormat:@"{\"aps\":{\"alert\":\"Testing\",\"id\":%@}}", ident];
        [BRHLogger add:@"sending notification %@", ident];
        [self.apns pushPayload:payload identifier:self.notificationSequenceId];
        self.notificationSequenceId += 1;
    }
    else if (self.sim) {
        NSNumber *identifier = [NSNumber numberWithInteger:self.notificationSequenceId];
        self.notificationSequenceId += 1;
        NSTimeInterval latency = [self ramp];
        NSTimeInterval when =[[NSDate date] timeIntervalSinceDate:self.startTime];
        [self recordLatency:latency forID:identifier withTime:when];
        [BRHLogger add:@"sim received ID %@ when: %f elapsed: %@", [identifier stringValue], when, [@(latency) stringValue]];
    }
}

- (void)emitterFired:(NSTimer *)timer
{
    [self emitNotification];
    self.emitter = [NSTimer scheduledTimerWithTimeInterval:self.emitInterval target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];
}

- (void)received:(NSNumber *)identifier timeOfArrival:(NSDate *)timeOfArrival contents:(NSDictionary *)contents
{
    [BRHLogger add: @"received - %@", contents];
    BRHOutstandingNotification *notification;

    if (self.remoteDriver) {

        if (self.latencies.count > 0) {
            BRHLatencyValue* tmp = [self.latencies lastObject];
            if (identifier.integerValue == tmp.identifier.integerValue) {
                return;
            }
        }

        notification = [BRHOutstandingNotification new];
        NSString *when = contents[@"when"];
        double dwhen = [when doubleValue];
        // dwhen += self.remoteDriver.deviceOffset;
        notification.when = [NSDate dateWithTimeIntervalSince1970: dwhen];
        notification.identifier = identifier;
    }
    else {
        notification = [self.outstandingNotifications objectForKey:identifier];
        if (notification == nil) {
            [BRHLogger add:@"received expired response to %d", [identifier integerValue]];
            return;
        }
    }

    NSTimeInterval latency = [timeOfArrival timeIntervalSinceDate:notification.when];
    [self recordLatency:latency forID:identifier withTime:[timeOfArrival timeIntervalSinceDate:self.startTime]];

    NSString *latencyString = [@(latency) stringValue];
    [BRHLogger add:@"received ID %@ when: %f elapsed: %@", [identifier stringValue], [timeOfArrival timeIntervalSinceDate:self.startTime], latencyString];
    [BRHEventLog add:@"received", [identifier stringValue], timeOfArrival, latencyString, nil];

    if (! self.remoteDriver) {
        
        // Check outstanding notifications to see if any have expired
        //
        NSMutableArray *toBeRemoved = [NSMutableArray arrayWithObject:notification.identifier];
        [self.outstandingNotifications enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (obj == notification) return;
            BRHOutstandingNotification *notification = obj;
            if ([notification.expiration timeIntervalSinceDate:timeOfArrival] < 0.0) {
                NSTimeInterval latency = [notification.expiration timeIntervalSinceDate:notification.when];
                [self recordLatency:latency forID:notification.identifier withTime:[notification.expiration timeIntervalSinceDate:self.startTime]];
                [BRHLogger add:@"*** forgetting notification ID %@ elapsed: %@", [identifier stringValue], [@(latency) stringValue]];
                [toBeRemoved addObject:key];
            }
        }];
        
        if (toBeRemoved.count) {
            [self.outstandingNotifications removeObjectsForKeys:toBeRemoved];
        }
    }
}

- (double)gaussian1
{
    double w, x1;
    do {
        x1 = 2.0 * arc4random() / UINT32_MAX - 1.0; // uniform distribution from -1 to +1
        double x2 = 2.0 * arc4random() / UINT32_MAX - 1.0;
        w = x1 * x1 + x2 * x2;
    } while ( w >= 1.0 );

    w = sqrt((-2.0 * log(w)) / w);

    double y = x1 * w;

    return y;
}

- (double)gaussian2
{
    double u1 = (double)arc4random() / UINT32_MAX; // uniform distribution from 0-1
    double u2 = (double)arc4random() / UINT32_MAX; // uniform distribution from 0-1
    double f1 = sqrt(-2 * log(u1));
    double f2 = 2 * M_PI * u2;
    double g = f1 * cos(f2); // gaussian distribution
    return g;
}

- (double)pseudoGaussian
{
    double s = 0.0;
    for (int count = 0; count < 6; ++count) {
        s += arc4random_uniform(100) + 1.0;  // 6 - 600
    }

    return s / 10.0; // .6 - 60.0
}

- (double)ramp
{
    return self.notificationSequenceId % 60 * 1.0;
}

- (void)recordLatency:(NSTimeInterval)latency forID:(NSNumber *)identifier withTime:(NSTimeInterval)when
{
    if (self.whenOffset < 0.0) {
        self.whenOffset = when;
    }

    // Calculate stats
    //
    BRHLatencyValue *stat = [BRHLatencyValue new];
    stat.identifier = identifier;
    stat.when = [NSNumber numberWithDouble:(when - self.whenOffset)];
    stat.value = [NSNumber numberWithDouble:latency];

    // Calculate the average value using the previous average and the current value
    //
    NSUInteger numLatencies = self.orderedLatencies.count;
    BRHLatencyValue *prev = numLatencies ? [self.latencies lastObject] : nil;
    stat.average = [NSNumber numberWithDouble:(latency + numLatencies * (prev ? prev.average.doubleValue : 0.0)) / (numLatencies + 1)];

    // Locate the proper position to insert the new value to keep the ordered array sorted
    //
    NSRange range = NSMakeRange(0, numLatencies);
    NSUInteger index = [self.orderedLatencies indexOfObject:stat inSortedRange:range options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];

    // Add new stat to all of the containers
    //
    [self.orderedLatencies insertObject:stat atIndex:index];
    [self.latencies addObject:stat];
    NSUInteger bin = [self.bins addValue:latency];
    numLatencies += 1;

    // Calculate median value from the sorted container
    //
    index = numLatencies / 2;
    double median = [[[self.orderedLatencies objectAtIndex:index] valueForKey:@"value"] doubleValue];
    if (numLatencies % 2 == 0) {
        median = (median + [[[self.orderedLatencies objectAtIndex:index - 1] valueForKey:@"value"] doubleValue]) / 2.0;
    }

    stat.median = [NSNumber numberWithDouble:median];

    // Alert interested parties that there is new data
    //
    [[NSNotificationCenter defaultCenter] postNotificationName:BRHNotificationDriverReceivedNotification
                                                        object:self
                                                      userInfo:@{@"value": stat, @"bin":[NSNumber numberWithUnsignedInteger:bin]}];
}

#pragma mark -
#pragma mark BRHAPNsClient Delegate Methods

- (void)sentNotification:(NSInteger)identifier
{
    BRHOutstandingNotification *notification = [BRHOutstandingNotification new];
    notification.when = [NSDate date];
    notification.identifier = @(identifier);
    notification.expiration = [notification.when dateByAddingTimeInterval:120.0];
    [self.outstandingNotifications setObject:notification forKey:notification.identifier];
    [BRHLogger add:@"sent notification ID %@", [notification.identifier stringValue]];
}

@end
