// BRHLogger.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLogger.h"

static NSString *BRHLoggerLogFileName = @"log.txt";

@interface BRHLogger ()

- (NSString *)add:(NSString *)format arguments:(va_list)argList;

@end

@implementation BRHLogger

- (instancetype)init
{
    return [super initWithFileName:BRHLoggerLogFileName];
}

+ (instancetype)sharedInstance
{
    static BRHLogger* singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHLogger new];
    });

    return singleton;
}

+ (NSString *)add:(NSString *)format, ...
{
    NSString *line = nil;
    if (format != nil) {
        va_list args;
        va_start(args, format);
        line = [[BRHLogger sharedInstance] add:format arguments:args];
        va_end(args);
    }

    return line;
}

+ (void)clear
{
    [[BRHLogger sharedInstance] clear];
}

- (NSString *)add:(NSString *)format arguments:(va_list)argList
{
    NSString *content = [[NSString alloc] initWithFormat:format arguments:argList];
    if (! [content hasSuffix:@"\n"]) content = [content stringByAppendingString:@"\n"];
    NSString *line = [NSString stringWithFormat:@"%@: %@", [self timestamp], content];
    [self addLine:line];
    NSLog(line);
    return line;
}

@end
