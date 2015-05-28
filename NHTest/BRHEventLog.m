//
//  BRHEventLog.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHEventLog.h"

@interface BRHEventLog () <UITextViewDelegate>

@property (nonatomic, strong) NSMutableString *log;
@property (nonatomic, strong) NSDateFormatter *dateTimeFormatter;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, assign) BOOL scrollToEnd;

- (NSString *)add:(NSString *)line;
- (void)flushToDisk;
- (void)writeLog:(NSTimer *)timer;
- (void)clear;

@end

@implementation BRHEventLog

+ (instancetype)sharedInstance
{
    static BRHEventLog *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [BRHEventLog new];
    });

    return singleton;
}

+ (NSString *)add:(NSString *)first, ...
{
    NSString* line = nil;
    if (first != nil) {
        va_list args;
        va_start(args, first);
        line = first;
        while ((first = va_arg(args, NSString*)) != nil) {
            line = [line stringByAppendingFormat:@",%@", first];
        }
        va_end(args);

        line = [[BRHEventLog sharedInstance] add:line];
    }

    return line;
}

+ (void)clear
{
    [[BRHEventLog sharedInstance] clear];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *url = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        self.logPath = url;
        
        self.textView = nil;
        self.log = [NSMutableString stringWithContentsOfURL:self.logPath encoding:NSUTF8StringEncoding error:nil];

        self.dateTimeFormatter = [[NSDateFormatter alloc] init];
        [self.dateTimeFormatter setDateFormat:@"yyyy-mm-dd HH:mm:ss.SSSSSS"];

        self.scrollToEnd = YES;
    }

    return self;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    self.scrollToEnd = NO;
}

- (NSString *)add:(NSString *)line
{
    if ([line hasSuffix:@"\n"] == NO) line = [line stringByAppendingString:@"\n"];
    line = [NSString stringWithFormat:@"%@,%@", [_dateTimeFormatter stringFromDate:[NSDate date]], line];
    [_log appendString:line];
    if (_textView) {
        CGFloat fromBottom = _textView.contentSize.height - _textView.contentOffset.y - 2 * _textView.bounds.size.height;
        [_textView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:line attributes:_textView.typingAttributes]];
        if (fromBottom < 0 || self.scrollToEnd == YES) {
            self.scrollToEnd = YES;
            [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length, 0)];
        }
    }
    [self flushToDisk];
    return line;
}

- (void)setLog:(NSMutableString *)log
{
    if (log == nil) log = [NSMutableString new];
    _log = log;
}

- (void)setTextView:(UITextView *)textView
{
    if (_textView) {
        _textView.delegate = nil;
    }
    
    _textView = textView;
    if (_textView) {
        _textView.text = _log;
        _textView.delegate = self;
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length, 0)];
    }
}

- (void)setLogPath:(NSURL *)logPath
{
    _logPath = [logPath URLByAppendingPathComponent:@"events.csv"];
    [self clear];
}

- (void)clear
{
    _log = [NSMutableString new];
    if (_textView) _textView.text = @"";
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
