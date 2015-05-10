//
//  APNS.h
//  APNS Pusher
//
//  Created by Simon Blommegård on 2011-10-13.
//  Copyright (c) 2011 Simon Blommegård. All rights reserved.
//

//#import <Cocoa/Cocoa.h>

@protocol SBAPNSDelegate

- (void)socketReceivedErrorResponse:(int)status identifier:(int)ident description:(NSString*)desc;
- (void)socketFinishedWriting:(NSInteger)ident;
- (void)socketReady;
- (void)socketClosed:(NSError*)err;

@end

@interface SBAPNS : NSObject

@property (nonatomic, weak) id <SBAPNSDelegate> delegate;
@property (nonatomic, assign, getter = isSandbox) BOOL sandbox;

+ (NSString*)host:(BOOL)inSandbox;
- (id)initWithIdentity:(SecIdentityRef)theIdentity token:(NSData*)token sandbox:(BOOL)theSandbox;
- (void)start;
- (void)stop;
- (BOOL)isConnected;
- (void)pushPayload:(NSString*)payload identifier:(NSInteger)identifier;

@end
