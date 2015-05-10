//
//  BRHLogger.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHLogger.h"

NSString* BRHLogContentsChanged = @"BRHLogContentsChanged";

@interface BRHLogger ()

@property (nonatomic, strong) NSMutableString *log;
@property (nonatomic, strong) NSDateFormatter *dateTimeFormatter;
@property (nonatomic, strong) NSTimer *flushTimer;

- (NSString *)add:(NSString *)format arguments:(va_list)argList;
- (void)flushToDisk;
- (void)writeLog:(NSTimer *)timer;

@end

@implementation BRHLogger

+ (instancetype)sharedInstance
{
    static BRHLogger *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHLogger new];
    });

    return singleton;
}

+ (NSString *)add:(NSString *)format, ...
{
    if (format != nil) {
        va_list args;
        va_start(args, format);
        return [[BRHLogger sharedInstance] add:format arguments:args];
    }

    return nil;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *url = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        _logPath = [url URLByAppendingPathComponent:@"log.txt"];
        _log = [NSMutableString stringWithContentsOfURL:_logPath encoding:NSUTF8StringEncoding error:nil];
        if (_log == nil) {
            _log = [NSMutableString new];
        }
        _dateTimeFormatter = [[NSDateFormatter alloc] init];
        [_dateTimeFormatter setDateFormat:@"HH:mm:ss.SSSSSS"];
    }

    return self;
}

- (NSString *)add:(NSString *)format arguments:(va_list)argList
{
    NSString *content = [[NSString alloc] initWithFormat:format arguments:argList];
    DDLogInfo(@"%@", content);
    if ([content hasSuffix:@"\n"] == NO) content = [content stringByAppendingString:@"\n"];
    NSString *line = [NSString stringWithFormat:@"%@: %@", [_dateTimeFormatter stringFromDate:[NSDate date]], content];
    [_log appendString:line];

    [[NSNotificationCenter defaultCenter] postNotificationName:BRHLogContentsChanged
                                                        object:self
                                                      userInfo:@{@"line":line}];
    [self flushToDisk];
    return line;
}

- (NSString *)contents
{
    return _log;
}

- (void)clear
{
    _log = [NSMutableString new];
    [[NSNotificationCenter defaultCenter] postNotificationName:BRHLogContentsChanged
                                                        object:self
                                                      userInfo:nil];
    [self flushToDisk];
}

- (void)save
{
    [self writeLog:nil];
}

- (void)flushToDisk
{
    if (_flushTimer == nil) {
        _flushTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(writeLog:) userInfo:nil repeats:NO];
    }
}

- (void)writeLog:(NSTimer *)timer
{
    if (_flushTimer == nil) return;
    [_flushTimer invalidate];
    _flushTimer = nil;

    void (^block)(void) = ^{
        [_log writeToURL:_logPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        DDLogDebug(@"wrote log to disk");
    };

    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    if (timer) {
        dispatch_async(q, block);
    }
    else {
        dispatch_sync(q, block);
    }
}

@end
