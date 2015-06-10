// BRHTextRecorder.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHTextRecorder.h"

@interface BRHTextRecorder () <UITextViewDelegate>

@property (copy, nonatomic) NSString *fileName;
@property (strong, nonatomic) NSMutableString *log;
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
        _logPath = nil;
        _textView = nil;
        _fileName = fileName;
        _log = nil;
        _dateTimeFormatter = [NSDateFormatter new];
        [_dateTimeFormatter setDateFormat:@"HH:mm:ss.SSSSSS"];
        _scrollToEnd = YES;

        [self setLogPath:nil];
    }

    return self;
}

- (void)dealloc
{
    if (self.flushTimer) {
        [self.flushTimer invalidate];
        self.flushTimer = nil;
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
    [self.log appendString:line];
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
    if (! logPath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        logPath = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    }
    
    _logPath = [logPath URLByAppendingPathComponent:self.fileName];
    self.log = [NSMutableString stringWithContentsOfURL:_logPath encoding:NSUTF8StringEncoding error:nil];
}

- (void)setLog:(NSMutableString *)log
{
    if (log == nil) {
        log = [NSMutableString new];
    }

    _log = log;

    if (_textView) {
        [self setTextView: _textView];
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
        _textView.text = _log;
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length, 0)];
    }
}

- (void)clear
{
    self.log = nil;
    [self flushToDisk];
}

- (void)save
{
    [self writeLog:nil];
}

- (void)flushToDisk
{
    if (self.flushTimer == nil) {
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(writeLog:) userInfo:nil repeats:NO];
    }
}

- (void)writeLog:(NSTimer *)timer
{
    if (! timer && self.flushTimer) {
        [self.flushTimer invalidate];
    }

    self.flushTimer = nil;

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
