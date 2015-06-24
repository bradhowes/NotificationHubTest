// BRHTextRecorder.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHTextRecorder.h"

@interface BRHTextRecorder () <UITextViewDelegate>

@property (copy, nonatomic) NSString *fileName;
@property (strong, nonatomic) NSMutableString *logText;
@property (strong, nonatomic) NSDateFormatter *dateTimeFormatter;
@property (strong, nonatomic) NSTimer *flushTimer;
@property (assign, nonatomic) BOOL scrollToEnd;

- (void)flushToDisk;
- (void)writeLog:(NSTimer *)timer;

@end

@implementation BRHTextRecorder

- (instancetype)initWithFileName:(NSString *)fileName
{
    self = [super init];
    if (self) {
        _fileName = fileName;
        _dateTimeFormatter = [NSDateFormatter new];
        [_dateTimeFormatter setDateFormat:@"HH:mm:ss.SSSSSS"];
        _logPath = nil;
        _textView = nil;
        _logText = [NSMutableString new];
        _scrollToEnd = YES;
        _saveInterval = 5.0;
        _flushTimer = nil;
        // [self setLogPath:nil];
    }

    return self;
}

- (void)dealloc
{
    if (_flushTimer) {
        [_flushTimer invalidate];
        _flushTimer = nil;
    }

    [self flushToDisk];
}

- (NSString *)timestamp
{
    return [_dateTimeFormatter stringFromDate:[NSDate date]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    self.scrollToEnd = NO;
}

- (NSString *)addLine:(NSString *)line
{
    [_logText appendString:line];
    if (self.textView) {
        dispatch_queue_t q = dispatch_get_main_queue();
        dispatch_async(q, ^() {
            CGFloat fromBottom = self.textView.contentSize.height - self.textView.contentOffset.y - 2 * self.textView.bounds.size.height;
            [self.textView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:line attributes:self.textView.typingAttributes]];
            if (fromBottom < 0 || self.scrollToEnd) {
                self.scrollToEnd = YES;
                [self.textView scrollRangeToVisible:NSMakeRange(self.textView.textStorage.length, 0)];
            }
        });
    }

    [self flushToDisk];

    return line;
}

- (void)setLogPath:(NSURL *)logPath
{
    if (_logPath) {
        [self writeLog:nil];
        _logPath = nil;
    }

    if (logPath) {
        _logPath = [logPath URLByAppendingPathComponent:self.fileName];
        if (_logText.length > 0) {
            [self writeLog:nil];
        }
    }
}

- (NSURL *)logPathForFolderPath:(NSURL *)folder
{
    NSLog(@"logPathForFolderPath: %@", folder.absoluteString);
    NSURL *path = [folder URLByAppendingPathComponent:self.fileName];
    NSLog(@"path: %@", path.absoluteString);
    return path;
}

- (NSString *)logContentForFolderPath:(NSURL *)folder
{
    NSLog(@"logContentForFolderPath: %@", folder.absoluteString);
    NSURL *path = [self logPathForFolderPath:folder];
    NSString *content = [NSString stringWithContentsOfURL:path encoding:NSUTF8StringEncoding error:nil];
    return content;
}

- (void)setLogText:(NSMutableString *)logText
{
    if (logText == nil) {
        logText = [NSMutableString new];
    }

    _logText = logText;

    if (_textView) {
        _textView.text = logText;
        [_textView scrollRangeToVisible:NSMakeRange(logText.length, 0)];
    }
}

- (void)setTextView:(UITextView *)textView
{
    if (_textView) {
        _textView.delegate = nil;
    }

    _textView = textView;

    if (_textView) {
        _textView.delegate = self;
        _textView.text = _logText;
        [_textView scrollRangeToVisible:NSMakeRange(_logText.length, 0)];
    }
}

- (void)clear
{
    [self writeLog:nil];
    self.logText = nil;
}

- (void)save
{
    [self writeLog:nil];
}

- (void)flushToDisk
{
    if (! _flushTimer) {
        _flushTimer = [NSTimer scheduledTimerWithTimeInterval:_saveInterval target:self selector:@selector(writeLog:) userInfo:nil repeats:NO];
    }
}

- (void)writeLog:(NSTimer *)timer
{
    if (! timer && self.flushTimer) {
        [self.flushTimer invalidate];
    }

    _flushTimer = nil;

    NSString *s = _logText;
    void (^block)(void) = ^{
        [s writeToURL:_logPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
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
