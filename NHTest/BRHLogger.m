//
//  BRHLogger.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHLogger.h"

@interface BRHLogger () <UITextViewDelegate>

@property (nonatomic, strong) NSMutableString *log;
@property (nonatomic, strong) NSDateFormatter *dateTimeFormatter;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, assign) BOOL scrollToEnd;

- (NSString *)add:(NSString *)format arguments:(va_list)argList;
- (void)flushToDisk;
- (void)writeLog:(NSTimer *)timer;
- (void)clear;

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

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *url = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        self.logPath = url;

        self.textView = nil;
        self.log = [NSMutableString stringWithContentsOfURL:self.logPath encoding:NSUTF8StringEncoding error:nil];

        self.dateTimeFormatter = [NSDateFormatter new];
        [self.dateTimeFormatter setDateFormat:@"HH:mm:ss.SSSSSS"];
        
        self.scrollToEnd = YES;
    }

    return self;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    self.scrollToEnd = NO;
}

- (NSString *)add:(NSString *)format arguments:(va_list)argList
{
    NSString *content = [[NSString alloc] initWithFormat:format arguments:argList];
    if ([content hasSuffix:@"\n"] == NO) content = [content stringByAppendingString:@"\n"];
    NSString *line = [NSString stringWithFormat:@"%@: %@", [_dateTimeFormatter stringFromDate:[NSDate date]], content];
    [_log appendString:line];
    if (_textView) {
        CGFloat fromBottom = _textView.contentSize.height - _textView.contentOffset.y - 2 * _textView.bounds.size.height;
        [_textView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:line attributes:_textView.typingAttributes]];
        if (fromBottom < 0 || self.scrollToEnd == YES) {
            self.scrollToEnd = YES;
            [_textView scrollRangeToVisible:NSMakeRange(_textView.textStorage.length, 0)];
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
        _textView.delegate = self;
        _textView.text = _log;
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length, 0)];
    }
}

- (void)setLogPath:(NSURL *)logPath
{
    _logPath = [logPath URLByAppendingPathComponent:@"log.txt"];
    [self clear];
}

- (NSString *)contents
{
    return _log;
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
