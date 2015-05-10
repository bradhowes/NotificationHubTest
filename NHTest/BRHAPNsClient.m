//
//  BRHAPNsClient.m
//  NHTest
//
//  Created by Brad Howes on 6/23/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Security/Security.h>
#import "GCDAsyncSocket.h"

#import "BRHAPNsClient.h"
#import "BRHLogger.h"
#import "Reachability.h"

@interface BRHAPNsClientPayload : NSObject

@property (nonatomic, strong) NSData *payload;
@property (nonatomic, assign) NSInteger identifier;

@end

@implementation BRHAPNsClientPayload

@end

@interface BRHAPNsClient () <GCDAsyncSocketDelegate>

@property (nonatomic, assign) SecIdentityRef identity;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) BRHAPNsClientPayload *cache;
@property (nonatomic, copy) NSData *token;
@property (nonatomic, strong) Reachability *reachability;

- (void)sendCachedNotification;
- (void)reachabilityChanged:(NSNotification *)notification;
- (NSData*)makePushPayloadFormat1For:(NSString*)payload identifier:(NSInteger)identifier;
- (NSData*)makePushPayloadFormat2For:(NSString*)payload identifier:(NSInteger)identifier;
- (void)retrySocketOpen:(NSTimer*)timer;

@end

@implementation BRHAPNsClient

+ (NSString*)host:(BOOL)inSandbox
{
    return inSandbox ? @"gateway.sandbox.push.apple.com" : @"gateway.push.apple.com";
}

- (id)initWithIdentity:(SecIdentityRef)theIdentity token:(NSData*)theToken sandbox:(BOOL)theSandbox
{
	if (self = [super init]) {
        self.identity = theIdentity;
        self.token = theToken;
        self.sandbox = theSandbox;
        self.socket = nil;
        self.cache = nil;
        self.reachability = [Reachability reachabilityForInternetConnection];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
        [self.reachability startNotifier];
    }

	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if (self.reachability) {
        [self.reachability stopNotifier];
        self.reachability = nil;
    }

    if (self.socket) {
        [self.socket disconnect];
        self.socket = nil;
    }
    
    if (_identity != NULL) {
        CFRelease(_identity);
    }
}

- (void)pushPayload:(NSString*)payload identifier:(NSInteger)identifier {
    NSData* data = [self makePushPayloadFormat2For:payload identifier:identifier];
    self.cache = [BRHAPNsClientPayload new];
    self.cache.payload = data;
    self.cache.identifier = identifier;
    [self sendCachedNotification];
}

- (void)sendCachedNotification
{
    if (self.cache && ! self.socket) {

        self.socket = [[GCDAsyncSocket alloc] init];
        [self.socket setDelegate:self delegateQueue:dispatch_get_main_queue()];

        NSString *host = [BRHAPNsClient host:_sandbox];
        NSError *error;
        [self.socket connectToHost:host onPort:2195 error:&error];
        if (error) {
            [BRHLogger add:@"failed to create APNs connection: %@", [error description]];
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

- (NSData*)makePushPayloadFormat1For:(NSString*)payload identifier:(NSInteger)identifier {

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
    [data appendData:self.token];
    
    NSData* payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    
    // payload length, network order
    uint16_t payloadLength = htons([payloadData length]);
    [data appendBytes:&payloadLength length:sizeof(uint16_t)];
    
    // payload
    [data appendData:payloadData];
    
    return data;
}

- (NSData*)makePushPayloadFormat2For:(NSString*)payload identifier:(NSInteger)identifier {
    
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
    [frame appendData:self.token];
    
    // item 2 - payload
    ++itemId;
    [frame appendBytes:&itemId length:sizeof(itemId)];

    // payload length, network order
    NSData* payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
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
    NSMutableData* data = [NSMutableData data];
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
    if (self.cache != nil) {
        [self.socket writeData:self.cache.payload withTimeout:2.0 tag:self.cache.identifier];
        self.cache = nil;
    }

    [self.socket readDataToLength:6 withTimeout:10.0 tag:-1];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [self.delegate sentNotification:tag];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    // Nothing from APNs so shutdown the connection
    [self.socket disconnect];
    self.socket = nil;
    return 0.0;
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

- (void)retrySocketOpen:(NSTimer*)timer
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
    if (self.cache) {
        [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(retrySocketOpen:) userInfo:nil repeats:NO];
    }
}

@end
