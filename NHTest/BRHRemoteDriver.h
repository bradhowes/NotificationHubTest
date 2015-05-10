//
//  BRHRemoteDriver.h
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHRemoteDriver : NSObject

@property (nonatomic, assign) double serverWhen;
@property (nonatomic, assign) double deviceOffset;

- (id)initWithDeviceToken:(NSData*)deviceToken host:(NSString*)host port:(int)port;
- (void)postRegistration;
- (void)deleteRegistration;

@end
