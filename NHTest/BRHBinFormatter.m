//
//  BRHBinFormatter.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHBinFormatter.h"

@implementation BRHBinFormatter

+ (BRHBinFormatter*)binFormatterWithMaxBins:(NSInteger)maxBins
{
    BRHBinFormatter* obj = [[BRHBinFormatter alloc] initWithMaxBins:maxBins];
    return obj;
}

- (id)initWithMaxBins:(NSInteger)maxBins
{
    if ((self = [super init]) != nil) {
        self.maxBins = maxBins;
    }
    
    return self;
}

/** Format a elapsed time value into HH:MM:SS format
 * @param obj the object to convert. Expects an object that responds to "doubleValue" method, like NSNumber
 * @return NSString representation of the given values
 */
- (NSString *)stringForObjectValue:(id)obj
{
    NSInteger value = [obj integerValue];
    if (value == 0) {
        return @"<1s";
    }
    else if (value == self.maxBins - 1) {
        return [NSString stringWithFormat:@"+%lds", (long)value];
    }
    else {
        return [NSString stringWithFormat:@"%lds", (long)value];
    }
}

@end

