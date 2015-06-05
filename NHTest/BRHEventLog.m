// BRHEventLog.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHEventLog.h"

static NSString *BRHEventLogFileName = @"events.csv";

@implementation BRHEventLog

+ (instancetype)sharedInstance
{
    static BRHEventLog* singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHEventLog new];
    });

    return singleton;
}

+ (NSString *)add:(NSString *)first, ...
{
    if (! first) return nil;
    va_list args;
    va_start(args, first);
    NSString *line = first;
    while ((first = va_arg(args, NSString *)) != nil) {
        line = [line stringByAppendingFormat:@",%@", first];
    }
    va_end(args);

    return [[BRHEventLog sharedInstance] addLine:line];
}

+ (void)clear
{
    [[BRHEventLog sharedInstance] clear];
}

- (instancetype)init
{
    return [super initWithFileName:BRHEventLogFileName];
}

- (NSString *)addLine:(NSString *)line
{
    if (! [line hasSuffix:@"\n"]) line = [line stringByAppendingString:@"\n"];
    line = [NSString stringWithFormat:@"%@,%@", [self timestamp], line];
    return [super addLine:line];
}

@end
