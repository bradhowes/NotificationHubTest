//
//  BRHLatencyValue.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHLatencyValue.h"

@implementation BRHLatencyValue

- (NSComparisonResult)compare:(BRHLatencyValue *)other
{
    return [self.value compare:other.value];
}

- (BOOL)duplicateOf:(BRHLatencyValue*)other
{
    return other.identifier.integerValue == self.identifier.integerValue;
}

@end

