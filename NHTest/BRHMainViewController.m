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
#import "BRHEventLog.h"
#import "BRHLogger.h"
#import "BRHMainViewController.h"
#import "BRHNotificationDriver.h"
#import "BRHTimeFormatter.h"

static void *const kKVOContext = (void *)&kKVOContext;

@interface BRHMainViewController ()

@property (nonatomic, strong) UIPopoverController *activityPopover;
@property (nonatomic, weak) BRHNotificationDriver *dataSource;

- (void)animateTextView:(UITextView *)view withConstraint:(NSLayoutConstraint *)constraint buttonIndex:(int)index;
- (NSURL *)makeLogDirectory;

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

    [BRHLogger sharedInstance].textView = self.log;
    [BRHEventLog sharedInstance].textView = self.events;

    self.playButton.enabled = YES;
    self.stopButton.enabled = NO;

    self.log.hidden = YES;
    self.events.hidden = YES;
    
    // Remove the "Stop" button
    //
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items removeObjectAtIndex:1];
    [self.toolbar setItems: items animated:NO];

    [self.dataSource addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:kKVOContext];

    self.runDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
}

- (void)animateTextView:(UITextView *)view withConstraint:(NSLayoutConstraint *)constraint buttonIndex:(int)index
{
    UIBarButtonItem* button = [self.toolbar.items objectAtIndex:index];
    if (view.hidden == YES) {
        [view scrollRangeToVisible:NSMakeRange(view.textStorage.length, 0)];
        button.tintColor = [UIColor cyanColor];
        constraint.constant = view.frame.size.height;
        [self.view layoutIfNeeded];

        view.hidden = NO;
        constraint.constant = 0;
        [UIView animateWithDuration:0.3f animations:^{
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            constraint.constant = 0;
            [self.view layoutIfNeeded];
        }];
    }
    else {
        button.tintColor = nil;
        constraint.constant = 0;
        [self.view layoutIfNeeded];

        constraint.constant = view.frame.size.height;
        [UIView animateWithDuration:0.3f animations:^{
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            view.hidden = YES;
            constraint.constant = 0;
            [view layoutIfNeeded];
        }];
    }
}

- (IBAction)showHideLogView:(id)sender
{
    if (self.log.hidden && ! self.events.hidden) {
        [self animateTextView:self.events withConstraint:self.eventsVerticalConstraint buttonIndex:4];
    }
    [self animateTextView:self.log withConstraint:self.logVerticalConstraint buttonIndex:2];
}

- (IBAction)showHideEventsView:(id)sender
{
    if (self.events.hidden && ! self.log.hidden) {
        [self animateTextView:self.log withConstraint:self.logVerticalConstraint buttonIndex:2];
    }
    [self animateTextView:self.events withConstraint:self.eventsVerticalConstraint buttonIndex:4];
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
    NSURL* logDir = [self makeLogDirectory];
    [BRHLogger sharedInstance].logPath = logDir;
    [BRHEventLog sharedInstance].logPath = logDir;
}

- (void)start
{
    BRHNotificationDriver *driver = self.dataSource;
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items replaceObjectAtIndex:0 withObject:self.stopButton];
    [self.toolbar setItems:items animated:YES];
    self.stopButton.enabled = YES;
    [self startRecording];

    [driver reset];

    // Clear all plots
    //
    [self.latencyPlot.hostedGraph.allPlots enumerateObjectsUsingBlock:^(CPTPlot* obj, NSUInteger idx, BOOL *stop) {
        [obj reloadData];
    }];
    
    [self.countBars.hostedGraph.allPlots enumerateObjectsUsingBlock:^(CPTPlot* obj, NSUInteger idx, BOOL *stop) {
        [obj reloadData];
    }];

    [BRHEventLog add:@"started", nil];
    [driver start];
}

- (void)stop
{
    BRHNotificationDriver *driver = self.dataSource;
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items replaceObjectAtIndex:0 withObject:self.playButton];
    [self.toolbar setItems:items animated:YES];
    [driver stop];
    [BRHEventLog add:@"stopped", nil];
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
    [objectsToShare addObject:[BRHEventLog sharedInstance].logPath];

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
