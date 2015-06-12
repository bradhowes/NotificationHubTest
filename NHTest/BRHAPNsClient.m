//  BRHAPNsClient.m
//  NHTest
//
//  Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Security/Security.h>
#import "GCDAsyncSocket.h"

#import "BRHAPNsClient.h"
#import "BRHLogger.h"
#import "Reachability.h"

/*!
 @brief Contents of an APNs push notification
 */
@interface BRHAPNsClientPayload : NSObject

/*!
 @brief The payload of the notification. Must be valid JSON.
 */
@property (strong, nonatomic) NSData *payload;

/*!
 @brief The unique identifier for the notification.
 */
@property (assign, nonatomic) NSInteger identifier;

@end

@implementation BRHAPNsClientPayload

@end

/*!
 @brief Private properties and methods for BRHAPNsClient class
 */
@interface BRHAPNsClient () <GCDAsyncSocketDelegate>

/*!
 @brief Reference to the certificate to use when communicating with APNs
 */
@property (assign, nonatomic) SecIdentityRef identity;
/*!
 @brief Socket connected to APNs server
 */
@property (strong, nonatomic) GCDAsyncSocket *socket;
/*!
 @brief The notification payload awaiting delivery.
 */
@property (strong, nonatomic) BRHAPNsClientPayload *cache;
/*!
 @brief YES if the socket is available to use
 */
@property (assign, nonatomic) BOOL socketReady;
/*!
 @brief The device token to send push notifications to
 */
@property (copy, nonatomic) NSData *deviceToken;
/*!
 @brief Network reachability detector.
 */
@property (strong, nonatomic) Reachability *reachability;

/*!
 @brief Send out any cached notification. Called after connection is reestablished with APNs.
 */
- (void)sendCachedNotification;

/*!
 @brief Notification that the network state has changed
 
 @param notification contents of the notification
 */
- (void)reachabilityChanged:(NSNotification *)notification;

/*!
 @brief Create a format 1 payload for APNs
 
 @param payload the JSON payload to send
 @param identifier the unique identifier for the push notification
 
 @return binary payload that conforms to APNs Format 1
 */
- (NSData *)makePushPayloadFormat1For:(NSString *)payload identifier:(NSInteger)identifier;

/*!
 @brief Create a format 2 payload for APNs
 
 @param payload the JSON payload to send
 @param identifier the unique identifier for the push notification
 
 @return binary payload that conforms to APNs Format 2
 */
- (NSData *)makePushPayloadFormat2For:(NSString *)payload identifier:(NSInteger)identifier;

/*!
 @brief Timer callback that attempts to establish a new APNs connection
 
 @param timer the timer that fired
 */
- (void)retrySocketOpen:(NSTimer *)timer;

@end

@implementation BRHAPNsClient

+ (NSString *)host:(BOOL)inSandbox
{
    return inSandbox ? @"gateway.sandbox.push.apple.com" : @"gateway.push.apple.com";
}

- (instancetype)initWithIdentity:(SecIdentityRef)theIdentity deviceToken:(NSData *)deviceToken sandbox:(BOOL)theSandbox
{
    if (self = [super init]) {
        _identity = theIdentity;
        _deviceToken = deviceToken;
        _sandbox = theSandbox;
        _socket = nil;
        _cache = nil;
        _socketReady = NO;
        _reachability = [Reachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
        [_reachability startNotifier];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_reachability) {
        [_reachability stopNotifier];
        _reachability = nil;
    }
    
    if (_socket) {
        [_socket disconnect];
        _socket = nil;
    }
    
    if (_identity != NULL) {
        CFRelease(_identity);
    }
}

- (void)pushPayload:(NSString *)payload identifier:(NSInteger)identifier {
    NSData *data = [self makePushPayloadFormat2For:payload identifier:identifier];
    self.cache = [BRHAPNsClientPayload new];
    self.cache.payload = data;
    self.cache.identifier = identifier;
    [self sendCachedNotification];
}

- (void)sendCachedNotification
{
    if (! self.cache) return;
    
    if (self.socketReady) {
        [self.socket writeData:self.cache.payload withTimeout:2.0 tag:self.cache.identifier];
        // !!!: The write could fail and we would then drop this. Perhaps wait to clear after write success?
        self.cache = nil;
        return;
    }
    
    if (! self.socket) {
        
        self.socket = [[GCDAsyncSocket alloc] init];
        [self.socket setDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        NSString *host = [BRHAPNsClient host:_sandbox];
        NSError *error;
        [self.socket connectToHost:host onPort:2195 error:&error];
        if (error) {
            [BRHLogger add:@"failed to create APNs connection: %@", [error description]];
            self.socketReady = NO;
            self.socket = nil;
            return;
        }
        
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        [options setObject:@[(__bridge id)_identity] forKey:(NSString *)kCFStreamSSLCertificates];
        [options setObject:host forKey:(NSString *)kCFStreamSSLPeerName];
        
        [self.socket startTLS:options];
    }
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    NetworkStatus status = [self.reachability currentReachabilityStatus];
    switch (status) {
        case NotReachable:
            [BRHLogger add:@"no network available"];
            break;
            
        case ReachableViaWiFi:
            [BRHLogger add:@"reachable via WIFI"];
            [self sendCachedNotification];
            break;
            
        case ReachableViaWWAN:
            [BRHLogger add:@"reachable via mobile network"];
            [self sendCachedNotification];
            break;
    }
}

- (NSData *)makePushPayloadFormat1For:(NSString *)payload identifier:(NSInteger)identifier {
    
    // Format: |COMMAND|ID|EXPIRY|TOKENLEN|TOKEN|PAYLOADLEN|PAYLOAD| */
    NSMutableData *data = [NSMutableData data];
    
    // command
    uint8_t command = 1; // extended
    [data appendBytes:&command length:sizeof(uint8_t)];
    
    // identifier
    uint32_t ident = (uint32_t)identifier;
    [data appendBytes:&ident length:sizeof(uint32_t)];
    
    // expiry, network order
    uint32_t expiry = htonl(time(NULL)+86400); // 1 day
    [data appendBytes:&expiry length:sizeof(uint32_t)];
    
    // token length, network order
    uint16_t tokenLength = htons(32);
    [data appendBytes:&tokenLength length:sizeof(uint16_t)];
    
    // token
    [data appendData:self.deviceToken];
    
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    
    // payload length, network order
    uint16_t payloadLength = htons([payloadData length]);
    [data appendBytes:&payloadLength length:sizeof(uint16_t)];
    
    // payload
    [data appendData:payloadData];
    
    return data;
}

- (NSData *)makePushPayloadFormat2For:(NSString *)payload identifier:(NSInteger)identifier {
    
    NSMutableData *frame = [NSMutableData data];
    uint8_t itemId = 1;
    uint16_t itemLength = 0;
    uint8_t priority = 10;
    
    if ([payload rangeOfString:@"content-available:"].location != NSNotFound) {
        priority = 5;
    }
    
    // item 1 - token
    [frame appendBytes:&itemId length:sizeof(itemId)];
    
    itemLength = htons(32);
    [frame appendBytes:&itemLength length:sizeof(itemLength)];
    [frame appendData:self.deviceToken];
    
    // item 2 - payload
    ++itemId;
    [frame appendBytes:&itemId length:sizeof(itemId)];
    
    // payload length, network order
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    itemLength = htons([payloadData length]);
    [frame appendBytes:&itemLength length:sizeof(itemLength)];
    [frame appendData:payloadData];
    
    // item 3 - notification identifier
    ++itemId;
    [frame appendBytes:&itemId length:sizeof(itemId)];
    uint32_t ident = (uint32_t)identifier;
    itemLength = htons(sizeof(ident));
    [frame appendBytes:&itemLength length:sizeof(itemLength)];
    [frame appendBytes:&ident length:sizeof(ident)];
    
    // item 4 - expiration
    ++itemId;
    [frame appendBytes:&itemId length:sizeof(itemId)];
    uint32_t expiry = htonl(time(NULL)+86400); // 1 day
    itemLength = htons(sizeof(expiry));
    [frame appendBytes:&itemLength length:sizeof(itemLength)];
    [frame appendBytes:&expiry length:sizeof(expiry)];
    
    // item 5 - priority
    ++itemId;
    [frame appendBytes:&itemId length:sizeof(itemId)];
    itemLength = htons(sizeof(priority));
    [frame appendBytes:&itemLength length:sizeof(itemLength)];
    [frame appendBytes:&priority length:sizeof(priority)];
    
    // Build push payload - |2|SIZE|FRAME
    NSMutableData *data = [NSMutableData data];
    uint8_t command = 2;
    [data appendBytes:&command length:sizeof(command)];
    uint32_t frameLength = htonl([frame length]);
    [data appendBytes:&frameLength length:sizeof(frameLength)];
    [data appendData:frame];
    
    return data;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    [BRHLogger add:@"APNs connection established"];
    self.socketReady = YES;
    [self sendCachedNotification];
    [self.socket readDataToLength:6 withTimeout:10.0 tag:-1];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [self.delegate sentNotification:tag];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    return 10.0;
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag != -1) return;
    
    uint8_t status;
    uint32_t identifier;
    
    [data getBytes:&status range:NSMakeRange(1, 1)];
    [data getBytes:&identifier range:NSMakeRange(2, 4)];
    
    NSString *desc;
    // http://developer.apple.com/library/mac/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/CommunicatingWIthAPS.html#//apple_ref/doc/uid/TP40008194-CH101-SW1
    switch (status) {
        case 0:
            desc = @"No errors encountered";
            break;
        case 1:
            desc = @"Processing error";
            break;
        case 2:
            desc = @"Missing device token";
            break;
        case 3:
            desc = @"Missing topic";
            break;
        case 4:
            desc = @"Missing payload";
            break;
        case 5:
            desc = @"Invalid token size";
            break;
        case 6:
            desc = @"Invalid topic size";
            break;
        case 7:
            desc = @"Invalid payload size";
            break;
        case 8:
            desc = @"Invalid token";
            break;
        case 10:
            desc = @"Shutdown";
            break;
        default:
            desc = @"None (unknown)";
            break;
    }
    
    [BRHLogger add:@"APNs response: %d %d %@", (int)status, identifier, desc];
}

- (void)retrySocketOpen:(NSTimer *)timer
{
    [self sendCachedNotification];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (err) {
        [BRHLogger add:@"APNs connection closed - error: %@", [err description]];
    }
    else {
        [BRHLogger add:@"APNs connection closed"];
    }
    
    self.socket = nil;
    self.socketReady = NO;
    if (self.cache) {
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(retrySocketOpen:) userInfo:nil repeats:NO];
    }
}

@end
