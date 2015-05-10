//
//  BRHAPNsClient.h
//  NHTest
//
//  Created by Brad Howes on 6/23/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BRHAPNsClientDelegate

- (void)sentNotification:(NSInteger)identifier;

@end

@interface BRHAPNsClient : NSObject

@property (nonatomic, weak) id <BRHAPNsClientDelegate> delegate;
@property (nonatomic, assign, getter = isSandbox) BOOL sandbox;

+ (NSString*)host:(BOOL)inSandbox;

- (id)initWithIdentity:(SecIdentityRef)theIdentity token:(NSData*)token sandbox:(BOOL)theSandbox;

- (void)pushPayload:(NSString*)payload identifier:(NSInteger)identifier;

@end
