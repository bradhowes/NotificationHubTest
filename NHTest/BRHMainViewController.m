//
//  BRHLogViewController.m
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import "BRHAppDelegate.h"
#import "BRHHistogram.h"
#import "BRHCountBars.h"
#import "BRHLatencyPlot.h"
#import "BRHLatencyValue.h"
#import "BRHLogger.h"
#import "BRHMainViewController.h"
#import "BRHNotificationDriver.h"
#import "BRHTimeFormatter.h"

static void *const kKVOContext = (void *)&kKVOContext;

@interface BRHMainViewController ()

@property (nonatomic, strong) UIPopoverController *activityPopover;
@property (nonatomic, weak) BRHNotificationDriver *dataSource;

- (void)animateFrame;
- (void)animateAlpha;
- (NSURL *)makeLogDirectory;
- (void)logChanged:(NSNotification *)notification;

@end

@implementation BRHMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Establish linkages
    //
    BRHAppDelegate* delegate = [UIApplication sharedApplication].delegate;
    BRHNotificationDriver* driver = delegate.notificationDriver;

    self.dataSource = driver;
    [self.latencyPlot initialize:driver];
    [self.countBars initialize:driver];

    // Receive notifications when log changes and notifications arrive
    //
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logChanged:) name:BRHLogContentsChanged object:[BRHLogger sharedInstance]];

    // Restore the log view with the last contents
    //
    self.log.attributedText = [[NSAttributedString alloc] initWithString:[[BRHLogger sharedInstance] contents] attributes:self.log.typingAttributes];

    self.playButton.enabled = YES;
    self.stopButton.enabled = NO;

    self.stats.text = @"";

    // Remove the "Stop" button
    //
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items removeObjectAtIndex:1];
    [self.toolbar setItems: items animated:NO];

    [self.dataSource addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:kKVOContext];

    self.runDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
}

- (void)logChanged:(NSNotification*)notification
{
    if (notification.userInfo == nil) {
        self.log.text = @"";
    }
    else {
        NSString *line = notification.userInfo[@"line"];
        [self.log.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:line attributes:_log.typingAttributes]];
        [self.log scrollRangeToVisible:NSMakeRange(_log.text.length, 0)];
    }
}

- (void)animateAlpha
{
    if (self.log.hidden == YES) {
        self.log.alpha = 0.0;
        self.log.hidden = NO;
        [UIView animateWithDuration:0.2f animations:^{
            self.log.alpha = 1.0;
        }];
    }
    else {
        self.log.alpha = 1.0;
        [UIView animateWithDuration:0.2f animations:^{
            self.log.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.log.hidden = YES;
        }];
    }
}

- (void)animateFrame
{
    if (self.log.hidden == YES) {
        UIBarButtonItem* button = [self.toolbar.items objectAtIndex:2];
        button.tintColor = [UIColor cyanColor];
        self.logVerticalConstraint.constant = self.countBars.frame.size.height;
        [self.log layoutIfNeeded];
        self.log.hidden = NO;
        [UIView animateWithDuration:0.2f animations:^{
            self.logVerticalConstraint.constant = 0;
            [self.log layoutIfNeeded];
        }];
    }
    else {
        UIBarButtonItem* button = [self.toolbar.items objectAtIndex:2];
        button.tintColor = nil;
        [UIView animateWithDuration:0.2f animations:^{
            self.logVerticalConstraint.constant = self.countBars.frame.size.height;
            [self.log layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.log.hidden = YES;
        }];
    }
}

- (IBAction)showHideLogView:(id)sender
{
    // [self animateAlpha];
    [self animateFrame];
}

- (NSURL*)makeLogDirectory
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];

    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *paths = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [paths objectAtIndex:0];

    NSURL *dir = [documentsDirectory URLByAppendingPathComponent:[dateFormatter stringFromDate:[NSDate date]]];
    NSError *err = nil;
    if ([fileManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&err] == NO) {
        DDLogError(@"failed to create dir: %@ err: %@", dir, [err description]);
    }

    self.runDirectory = dir;
    return dir;
}

- (void)startRecording
{
    // Begin recording into a new directory
    //
    NSURL *url = [[self makeLogDirectory] URLByAppendingPathComponent:@"log.txt"];
    DDLogDebug(@"URL: %@", [url description]);
    [BRHLogger sharedInstance].logPath = url;
    [[BRHLogger sharedInstance] clear];
}

- (void)start
{
    BRHNotificationDriver *driver = self.dataSource;
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items replaceObjectAtIndex:0 withObject:self.stopButton];
    [self.toolbar setItems:items animated:YES];
    self.stopButton.enabled = YES;
    [self startRecording];
    self.stats.text = @"";

    [driver reset];

    // Clear all plots
    //
    [self.latencyPlot.hostedGraph.allPlots enumerateObjectsUsingBlock:^(CPTPlot* obj, NSUInteger idx, BOOL *stop) {
        [obj reloadData];
    }];
    
    [self.countBars.hostedGraph.allPlots enumerateObjectsUsingBlock:^(CPTPlot* obj, NSUInteger idx, BOOL *stop) {
        [obj reloadData];
    }];

    [driver start];
}

- (void)stop
{
    BRHNotificationDriver *driver = self.dataSource;
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items replaceObjectAtIndex:0 withObject:self.playButton];
    [self.toolbar setItems:items animated:YES];
    [driver stop];
}

- (IBAction)startStop:(id)sender
{
    if (sender == self.playButton) {
        [self start];
    }
    else {
        [self stop];
    }
}

- (IBAction)clearLogView:(id)sender {
    [[BRHLogger sharedInstance] clear];
}

- (IBAction)share:(id)sender
{
    NSMutableData *pdfData = [[NSMutableData alloc] init];
    CGDataConsumerRef dataConsumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfData);
    CGContextRef pdfContext = CGPDFContextCreate(dataConsumer, NULL, NULL);
    CPTPushCGContext(pdfContext);

    [self.latencyPlot renderPDF:pdfContext];
    [self.countBars renderPDF:pdfContext];

    CGPDFContextClose(pdfContext);
    CPTPopCGContext();
    CGContextRelease(pdfContext);

    CGDataConsumerRelease(dataConsumer);

    NSURL *plotUrl = [self.runDirectory URLByAppendingPathComponent:@"plots.pdf"];
    [pdfData writeToURL:plotUrl atomically:YES];

    NSMutableArray *objectsToShare = [NSMutableArray new];
    [objectsToShare addObject:plotUrl];
    [objectsToShare addObject:[BRHLogger sharedInstance].logPath];

    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];

#if 0
    // Exclude all activities except AirDrop.
    NSArray *excludedActivities = @[UIActivityTypePostToTwitter,
                                    UIActivityTypePostToWeibo,
                                    UIActivityTypeAssignToContact,
                                    UIActivityTypeSaveToCameraRoll,
                                    UIActivityTypeAddToReadingList,
                                    UIActivityTypePostToFlickr,
                                    UIActivityTypePostToVimeo,
                                    UIActivityTypePostToTencentWeibo];
    controller.excludedActivityTypes = nil; // excludedActivities;
#endif

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self presentViewController:controller animated:YES completion:nil];
    }
    else {
        if (! [self.activityPopover isPopoverVisible]) {
            self.activityPopover = [[UIPopoverController alloc] initWithContentViewController:controller];
            [self.activityPopover presentPopoverFromBarButtonItem:self.shareButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
        else {
            [self.activityPopover dismissPopoverAnimated:YES];
        }
    }
}

- (void)refreshDisplay
{
    [self.latencyPlot refreshDisplay];
    [self.countBars refreshDisplay];
}

- (void)update:(NSNotification*)notification
{
    NSNumberFormatter* fmt = [NSNumberFormatter new];
    [fmt setNumberStyle:NSNumberFormatterDecimalStyle];
    [fmt setMaximumFractionDigits:3];

    BRHLatencyValue *stat = [notification.userInfo objectForKeyedSubscript:@"value"];
    self.stats.text = [NSString stringWithFormat:@"Med: %@\nAvg: %@\nMin: %@\nMax: %@\nCnt: %lu",
                       [fmt stringFromNumber:stat.median],
                       [fmt stringFromNumber:stat.average],
                       [fmt stringFromNumber:self.dataSource.min.value],
                       [fmt stringFromNumber:self.dataSource.max.value],
                       (unsigned long)self.dataSource.latencies.count];
    
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kKVOContext && [keyPath isEqualToString:@"running"] && [object isEqual:self.dataSource] ) {
        NSNumber *value = [change valueForKey:NSKeyValueChangeNewKey];
        if (value.boolValue == NO) {
            [self stop];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


@end
