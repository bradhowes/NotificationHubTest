//
//  BRHRemoteDriver.h
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import "BRHNotificationDriver.h"

@interface BRHRemoteDriver : BRHNotificationDriver

@property (assign, nonatomic) double serverWhen;
@property (assign, nonatomic) double deviceServerDelta;

@end
