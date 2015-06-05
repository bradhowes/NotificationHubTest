// BRHMainController.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHAppDelegate.h"
#import "BRHLatencyHistogramPlot.h"
#import "BRHEventLog.h"
#import "BRHHistogram.h"
#import "BRHLatencyByTimePlot.h"
#import "BRHLogger.h"
#import "BRHMainViewController.h"
#import "BRHNotificationDriver.h"
#import "BRHRecordingsViewController.h"
#import "BRHRunData.h"

static void* const kKVOContext = (void *)&kKVOContext;

@interface BRHMainViewController ()

@property (strong, nonatomic) UIPopoverController *activityPopover;
@property (strong, nonatomic) UIView *lowerView;

- (void)animateLowerView:(UIView *)view;
- (void)start;
- (void)stop;

@end

@implementation BRHMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [BRHLogger sharedInstance].textView = self.logView;
    [BRHEventLog sharedInstance].textView = self.eventsView;

    self.playButton.enabled = YES;
    self.stopButton.enabled = NO;

    self.logView.hidden = YES;
    self.eventsView.hidden = YES;
    self.recordingsView.hidden = YES;
    self.lowerView = nil;

    // Remove the "Stop" button
    //
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items removeObjectAtIndex:1];
    [self.toolbar setItems: items animated:NO];

    BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    [self setRunData:delegate.runData];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Locate the embedded seque for the recordingsViewController and establish a relationship with the
    // controller.
    //
    NSString *identifier = [segue identifier];
    if (identifier && [identifier isEqualToString:@"recordingsViewController"]) {
        UINavigationController *nc = segue.destinationViewController;
        self.recordingsViewController = (BRHRecordingsViewController *)[nc topViewController];
        BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
        self.recordingsViewController.managedObjectContext = delegate.managedObjectContext;
        self.recordingsViewController.buttonItem = self.recordingsButton;
        
        if (self.dropboxUploader) {
            self.recordingsViewController.dropboxUploader = self.dropboxUploader;
        }
    }
}

- (void)animateLowerView:(UIView *)view
{
    NSLayoutConstraint *top = nil;
    NSLayoutConstraint *bottom = nil;
    for (NSLayoutConstraint* each in self.view.constraints) {
        if (each.firstItem == view) {
            if (each.firstAttribute == NSLayoutAttributeTop) {
                top = each;
            }
            else if (each.firstAttribute == NSLayoutAttributeBottom) {
                bottom = each;
            }
        }
    }
    
    UIBarButtonItem *button = [self.toolbar.items objectAtIndex:view.tag];

    if (view.hidden) {

        if (self.lowerView != nil) [self animateLowerView:self.lowerView];
        self.lowerView = view;

        // [view scrollRangeToVisible:NSMakeRange(view.textStorage.length, 0)];
        button.tintColor = [UIColor cyanColor];

        bottom.constant = view.frame.size.height;
        top.constant = view.frame.size.height;
        [self.view layoutIfNeeded];

        view.hidden = NO;

        top.constant = 0;
        bottom.constant = 0;
        [UIView animateWithDuration:0.3f animations:^{
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self.view layoutIfNeeded];
        }];
    }
    else {
        button.tintColor = nil;
        self.lowerView = nil;

        top.constant = 0;
        bottom.constant = 0;
        [self.view layoutIfNeeded];

        bottom.constant = view.frame.size.height;
        top.constant = view.frame.size.height;
        [UIView animateWithDuration:0.3f animations:^{
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            view.hidden = YES;
            [view layoutIfNeeded];
        }];
    }
}

- (IBAction)showHideLogView:(id)sender
{
    [self animateLowerView:self.logView];
}

- (IBAction)showHideEventsView:(id)sender
{
    [self animateLowerView:self.eventsView];
}

- (IBAction)showHideRecordingsView:(id)sender
{
    [self animateLowerView:self.recordingsView];
}

- (void)showButton:(UIBarButtonItem *)button
{
    button.enabled = YES;
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items replaceObjectAtIndex:0 withObject:button];
    [self.toolbar setItems:items animated:YES];
}

- (void)start
{
    [self showButton:self.stopButton];
    BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    [self setRunData:[delegate startRun]];
}

- (void)stop
{
    BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    [delegate stopRun];
    [self showButton:self.playButton];
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

- (void)setRunData:(BRHRunData *)runData
{
    if (runData) {
        [self.latencyPlot useDataSource:runData.samples title:runData.name emitInterval:runData.emitInterval];
        [self.countBars initialize:runData.bins];
    }
}

- (void)setDropboxUploader:(BRHDropboxUploader *)dropboxUploader
{
    _dropboxUploader = dropboxUploader;
    if (self.recordingsViewController) {
        self.recordingsViewController.dropboxUploader = dropboxUploader;
    }
}

#if 0

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

#endif

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
