//
//  BRHTimeFormatter.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHTimeFormatter.h"

@implementation BRHTimeFormatter

/** Format a elapsed time value into HH:MM:SS format
 * @param obj the object to convert. Expects an object that responds to "doubleValue" method, like NSNumber
 * @return NSString representation of the given values
 */
- (NSString *)stringForObjectValue:(id)obj
{
    double value = [obj doubleValue];
    NSInteger hours = 0;
    if (value >= 3600.0) {
        hours = value / 3600.0;
        value -= hours * 3600.0;
    }
    
    NSInteger minutes = 0;
    if (value >= 60.0) {
        minutes = value / 60.0;
        value -= minutes * 60.0;
    }
    
    NSInteger seconds = value;
    value -= seconds;
    NSString *ss = [NSString stringWithFormat:@"%.2f", value];

    // Strip off any trailing '0' characters
    //
    ss = [ss substringFromIndex:1];
    while (ss.length > 0 && [ss characterAtIndex:(ss.length - 1)] == '0') {
        ss = [ss substringToIndex:(ss.length - 1)];
    }

    // Strip off the '.' if nothing following it
    //
    if (ss.length == 1) ss = @"";

    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%2.2ld:%2.2ld%@", (long)hours, (long)minutes, (long)seconds, ss];
    }
    else if (minutes > 0) {
        return [NSString stringWithFormat:@"%ld:%2.2ld%@", (long)minutes, (long)seconds, ss];
    }
    else {
        return [NSString stringWithFormat:@"%ld%@s", (long)seconds, ss];
    }
}

@end
