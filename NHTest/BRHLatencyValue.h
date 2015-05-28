//
//  BRHLatencyValue.h
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHLatencyValue : NSObject

@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong) NSNumber *when;
@property (nonatomic, strong) NSNumber *value;
@property (nonatomic, strong) NSNumber *median;
@property (nonatomic, strong) NSNumber *average;

- (BOOL)isDuplicateOf:(BRHLatencyValue*)other;

@end
