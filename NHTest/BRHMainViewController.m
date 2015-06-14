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
#import "BRHRecordingsViewController.h"
#import "BRHRunData.h"
#import "BRHSettingsStore.h"
#import "BRHUserSettings.h"
#import "InAppSettingsKit/IASKAppSettingsViewController.h"

static void* const kKVOContext = (void *)&kKVOContext;

@interface BRHMainViewController () <IASKSettingsDelegate>

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

    // Attach widgets to the text loggers
    //
    [BRHLogger sharedInstance].textView = self.logView;
    [BRHEventLog sharedInstance].textView = self.eventsView;

    self.playButton.enabled = YES;
    self.stopButton.enabled = NO;
    self.logView.hidden = YES;
    self.eventsView.hidden = YES;
    self.recordingsView.hidden = YES;
    self.lowerView = nil;

    self.settingsViewController = [IASKAppSettingsViewController new];
    self.settingsViewController.delegate = self;
    self.settingsViewController.settingsStore = [BRHSettingsStore new];

    // Remove the "Stop" button so that there in only a "Play" one shown
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
    [self.toolbar setItems:items animated:YES];
}

- (void)start
{
    [self showButton:self.stopButton];
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
        [self stop];
    }
}

- (void)setRunData:(BRHRunData *)runData
{
    if (runData) {
        self.latencyPlot.runData = runData;
        self.countBars.runData = runData;
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

/*!
 * @brief Delegate method called when user clicks on button in view.
 *
 * @note: For this to work on iPad devices, we need the view to have a lastButton attribute defined. This is a hack of the IASK source code.
 *
 * @param sender the view (us) -- sort of meaningless here
 * @param specifier definition of the setting values
 */
- (void)settingsViewController:(id)sender buttonTappedForSpecifier:(IASKSpecifier *)specifier {
    NSLog(@"buttonTappedForSpecifier - %@", specifier.key);
    if (![specifier.key isEqualToString:@"dropboxLinkButtonTextSetting"]) {
        return;
    }

    BRHUserSettings *settings = [BRHUserSettings userSettings];
    if (! settings.useDropbox) {
        BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
        [delegate enableDropbox:YES];
        return;
    }

    NSString *title = @"Dropbox";
    NSString *msg = @"Are you sure you want to unlink from Dropbox? This will prevent the app from saving future recordings to your Drobox folder.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action){
                                                         }];
    
    UIAlertAction *unlinkAction = [UIAlertAction actionWithTitle:@"Confirm"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *action) {
                                                             BRHAppDelegate *delegate = [UIApplication sharedApplication].delegate;
                                                             [delegate enableDropbox:NO];
                                                         }];
    [alert addAction:cancelAction];
    [alert addAction:unlinkAction];
    
    [self.presentedViewController presentViewController:alert animated:YES completion:^(){
        [self.settingsViewController.tableView reloadData];
    }];
}

/*!
 * @brief Delegate method called when the view is dismissed and the settings have been saved.
 *
 * @param sender the view that is no longer around
 */
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender {
    NSLog(@"BRHSettingsViewController settingsViewControllerDidEnd:");
    [[BRHUserSettings userSettings] readPreferences];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
