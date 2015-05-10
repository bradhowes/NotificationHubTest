//
//  APNS.m
//  APNS Pusher
//
//  Created by Simon Blommegård on 2011-10-13.
//  Copyright (c) 2011 Simon Blommegård. All rights reserved.
//

#import "SBAPNS.h"
#import <Security/Security.h>
#import "GCDAsyncSocket.h"

@interface SBAPNS () <GCDAsyncSocketDelegate>

@property (nonatomic, assign) SecIdentityRef identity;
@property (nonatomic, strong) GCDAsyncSocket* socket;
@property (nonatomic, copy) NSData* token;
@property (nonatomic, assign) BOOL reading;
@property (nonatomic, assign) BOOL ready;

- (void)makeSocket;

@end

@implementation SBAPNS

+ (NSString*)host:(BOOL)inSandbox
{
    return inSandbox ? @"gateway.sandbox.push.apple.com" : @"gateway.push.apple.com";
}

- (id)initWithIdentity:(SecIdentityRef)theIdentity token:(NSData*)theToken sandbox:(BOOL)theSandbox {
	if (self = [super init]) {
        self.identity = theIdentity;
        self.token = theToken;
        self.sandbox = theSandbox;
        self.ready = NO;
        self.reading = NO;
	}
	return self;
}

- (void)dealloc {
    if (_identity != NULL)
        CFRelease(_identity);
}

- (void)makeSocket
{
    DDLogInfo(@"makeSocket BEGIN");

    self.ready = NO;
    self.socket = [[GCDAsyncSocket alloc] init];
    [self.socket setDelegate:self delegateQueue:dispatch_get_main_queue()];

    NSString* host = [SBAPNS host:_sandbox];

    NSError* error;
    [self.socket connectToHost:host onPort:2195 error:&error];
    if (error) {
        DDLogError(@"failed to connect: %@", error);
        self.socket = nil;
    }
    else {
        DDLogInfo(@"beginning TLS");
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        [options setObject:@[(__bridge id)_identity] forKey:(NSString *)kCFStreamSSLCertificates];
        [options setObject:host forKey:(NSString *)kCFStreamSSLPeerName];
        [self.socket startTLS:options];
    }
}

#pragma mark - Public

- (void)start
{
    [self makeSocket];
}

- (void)stop
{
    [self.socket disconnect];
    self.socket = nil;
}

- (BOOL)isConnected
{
    return self.socket != nil && self.ready == YES ? YES : NO;
}

- (void)pushPayload:(NSString*)payload identifier:(NSInteger)identifier {
    DDLogInfo(@"pushPayload BEGIN - %ld", (long)identifier);
    if (self.socket.isSecure == NO) {
        DDLogError(@"attempted to send on invalid socket");
        return;
    }

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

	[self.socket writeData:data withTimeout:2.0 tag:identifier];

    if (self.reading == NO) {
        [self.socket readDataToLength:6 withTimeout:5.0 tag:-1];
        self.reading = YES;
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    DDLogInfo(@"socketDidSecure BEGIN");
    self.ready = YES;
    [self.delegate socketReady];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    DDLogDebug(@"socket:didWriteDataWithTag: %ld", tag);
    [self.delegate socketFinishedWriting:tag];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    DDLogDebug(@"socket read timedout");
    return 5.0;
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	if (tag != -1) return;
    DDLogDebug(@"socket:didReadData:withTag: %ld", tag);

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

    if (status != 0) {
        NSLog(@"socket didReadData: %d %d %@", (int)status, identifier, desc);
        [self.delegate socketReceivedErrorResponse:status identifier:identifier description:desc];
        self.reading = NO;
        self.ready = NO;
        [self stop];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    DDLogError(@"socketDidDisconnect - error: %@", [err description]);
    [self.delegate socketClosed:err];
    self.socket = nil;
    self.reading = NO;
    self.ready = NO;
}

@end
