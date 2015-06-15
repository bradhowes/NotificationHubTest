//
//  BRHTimeFormatter.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHTimeFormatter.h"

@implementation BRHTimeFormatter

+ (instancetype)sharedTimeFormatter
{
    static BRHTimeFormatter *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHTimeFormatter new];
    });
    return singleton;
}

/** Format a elapsed time value into HHhMMmSSs format
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

    NSMutableString *result = [NSMutableString new];
    if (hours) {
        [result appendFormat:@"%ldh", (long)hours];
    }
    
    if (minutes) {
        [result appendFormat:@"%ldm", (long)minutes];
    }

    if (seconds || ss.length) {
        [result appendFormat:@"%ld%@s", (long)seconds, ss];
    }

    return result;
}

@end
