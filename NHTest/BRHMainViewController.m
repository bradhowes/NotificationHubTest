// BRHMainController.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHAppDelegate.h"
#import "BRHLatencyHistogramGraph.h"
#import "BRHEventLog.h"
#import "BRHHistogram.h"
#import "BRHLatencyByTimeGraph.h"
#import "BRHLogger.h"
#import "BRHMainViewController.h"
#import "BRHNotificationDriver.h"
#import "BRHRecordingInfo.h"
#import "BRHRecordingsViewController.h"
#import "BRHRunData.h"
#import "BRHSettingsStore.h"
#import "BRHSettingsViewDelegate.h"
#import "BRHUserSettings.h"
#import "InAppSettingsKit/IASKAppSettingsViewController.h"

@interface BRHMainViewController ()

@property (strong, nonatomic) UIView *lowerView;

- (void)animateLowerView:(UIView *)view;

@end

@implementation BRHMainViewController

#pragma mark - View Management

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.playButton.enabled = YES;
    self.stopButton.enabled = NO;
    self.logView.hidden = YES;
    self.eventsView.hidden = YES;
    self.recordingsView.hidden = YES;
    self.lowerView = nil;

    self.settingsViewDelegate = [BRHSettingsViewDelegate new];
    self.settingsViewController = [IASKAppSettingsViewController new];
    self.settingsViewController.settingsStore = [BRHSettingsStore new];

    self.settingsViewDelegate.settingsViewController = self.settingsViewController;
    self.settingsViewDelegate.mainWindowController = self;
    self.settingsViewController.delegate = self.settingsViewDelegate;

    // Remove the "Stop" button so that there in only a "Play" one shown
    //
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items removeObjectAtIndex:1];
    [self.toolbar setItems: items animated:NO];

    // BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    // self.recordingInfo = delegate.recordingInfo;
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
        self.recordingsViewController.buttonItem = self.recordingsButton;
        if (self.dropboxUploader) {
            self.recordingsViewController.dropboxUploader = self.dropboxUploader;
        }
    }
}

- (void)animateLowerView:(UIView *)view
{
    // Locate the constraints that we will use to swipe in the given view
    //
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

        // Revealing a new view by sliding it up into place. If there is another view already there,
        // slide it down first.
        //
        if (self.lowerView) {
            [self animateLowerView:self.lowerView];
        }

        self.lowerView = view;

        button.tintColor = [UIColor cyanColor];

        // Set the starting position for the constaints. These will go to zero in an animation, causing the view to
        // slide into view.
        //
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
        
        // Slide down an existing view.
        //
        button.tintColor = nil;
        self.lowerView = nil;

        top.constant = 0;
        bottom.constant = 0;
        [self.view layoutIfNeeded];

        // Set the final constraint position for the animation.
        //
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

- (IBAction)showSettings:(id)sender
{
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:self.settingsViewController];
    self.settingsViewController.showDoneButton = YES;
    [self presentViewController:aNavController animated:YES completion:^(){
        ;
    }];
}

- (void)showButton:(UIBarButtonItem *)button
{
    button.enabled = YES;
    NSMutableArray *items = [self.toolbar.items mutableCopy];
    [items replaceObjectAtIndex:0 withObject:button];
    [self.toolbar setItems:items animated:NO];
}

#pragma mark - Recordings

- (void)start
{
    [self showButton:self.stopButton];
    self.stopButton.tintColor = [UIColor redColor];
    BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    [delegate startRun];
}

- (void)stop
{
    [self showButton:self.playButton];
    BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
    [delegate stopRun];
}

- (IBAction)startStop:(id)sender
{
    if (sender == self.playButton) {
        [self start];
    }
    else {
        NSString *title = @"Stop Run?";
        NSString *msg = @"Do you wish to stop running?";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self stop];
        }];

        UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        }];
        
        [alert addAction:yesAction];
        [alert addAction:noAction];
        
        UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }
        
        // Present the view controller using the popover style.
        alert.modalPresentationStyle = UIModalPresentationPopover;
        [vc presentViewController:alert animated: YES completion: nil];

        UIPopoverPresentationController *presentationController = [alert popoverPresentationController];
        presentationController.permittedArrowDirections = UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight;
        presentationController.barButtonItem = self.stopButton;
    }
}

- (void)shareRecording:(BRHRecordingInfo *)recordingInfo atButton:(UIButton *)button
{
    // Create PDF context to draw into.
    //
    NSMutableData *pdfData = [[NSMutableData alloc] init];
    CGDataConsumerRef dataConsumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfData);
    CGContextRef pdfContext = CGPDFContextCreate(dataConsumer, NULL, NULL);
    CPTPushCGContext(pdfContext);
    
    // Draw the charts as PDFs
    //
    [self.latencyPlot renderPDF:pdfContext];
    [self.countBars renderPDF:pdfContext];

    CGPDFContextClose(pdfContext);
    CPTPopCGContext();
    CGContextRelease(pdfContext);

    CGDataConsumerRelease(dataConsumer);

    NSURL *plotUrl = [recordingInfo.folderURL URLByAppendingPathComponent:@"plots.pdf"];
    [pdfData writeToURL:plotUrl atomically:YES];

    NSMutableArray *objectsToShare = [NSMutableArray new];
    [objectsToShare addObject:plotUrl];
    [objectsToShare addObject:[[BRHLogger sharedInstance] logPathForFolderPath:recordingInfo.folderURL]];
    [objectsToShare addObject:[[BRHEventLog sharedInstance] logPathForFolderPath:recordingInfo.folderURL]];

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

    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }

    // Present the view controller using the popover style.
    controller.modalPresentationStyle = UIModalPresentationPopover;
    [vc presentViewController:controller animated: YES completion: nil];
    
    UIPopoverPresentationController *presentationController = [controller popoverPresentationController];
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight;
    presentationController.sourceView = button;
    presentationController.sourceRect = button.frame;
}

- (void)setRecordingInfo:(BRHRecordingInfo *)recordingInfo
{
    self.latencyPlot.recordingInfo = recordingInfo;
    self.countBars.recordingInfo = recordingInfo;

    if (! recordingInfo.wasRecorded) {

        if (! recordingInfo.recordingNow) {
            
            // New recording is about to start -- start with new log files
            //
            [[BRHLogger sharedInstance] clear];
            [[BRHEventLog sharedInstance] clear];

            [BRHLogger add:@"new recording"];
            [BRHEventLog add:@"newRecording", nil];
        }

        // Switch to showing the recording logs
        //
        [BRHLogger sharedInstance].textView = _logView;
        [BRHLogger sharedInstance].logPath = recordingInfo.folderURL;

        [BRHEventLog sharedInstance].textView = _eventsView;
        [BRHEventLog sharedInstance].logPath = recordingInfo.folderURL;
    }
    else {
        
        // Prior recording. Show the contents of the recording, not the active log devices.
        //
        [BRHLogger sharedInstance].textView = nil;
        [BRHEventLog sharedInstance].textView = nil;

        NSString *text = [[BRHLogger sharedInstance] logContentForFolderPath:recordingInfo.folderURL];
        _logView.text = text;
        [_logView scrollRangeToVisible:NSMakeRange(0, 0)];

        text = [[BRHEventLog sharedInstance] logContentForFolderPath:recordingInfo.folderURL];
        _eventsView.text = text;
        [_eventsView scrollRangeToVisible:NSMakeRange(0, 0)];
    }
}

- (void)setDropboxUploader:(BRHDropboxUploader *)dropboxUploader
{
    _dropboxUploader = dropboxUploader;
    if (self.recordingsViewController) {
        self.recordingsViewController.dropboxUploader = dropboxUploader;
    }

    [self.settingsViewController.tableView reloadData];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
