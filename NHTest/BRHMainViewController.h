// BRHMainController.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

@class BRHDropboxUploader;
@class BRHLatencyHistogramPlot;
@class BRHLatencyByTimePlot;
@class BRHRecordingsViewController;
@class BRHRunData;

@interface BRHMainViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *stopButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *recordingsButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsButton;

@property (strong, nonatomic) IBOutlet BRHLatencyByTimePlot *latencyPlot;
@property (strong, nonatomic) IBOutlet BRHLatencyHistogramPlot *countBars;
@property (strong, nonatomic) IBOutlet UITextView *logView;
@property (strong, nonatomic) IBOutlet UITextView *eventsView;
@property (strong, nonatomic) IBOutlet UIView *recordingsView;
@property (strong, nonatomic) BRHRecordingsViewController *recordingsViewController;
@property (strong, nonatomic) BRHDropboxUploader *dropboxUploader;

- (IBAction)startStop:(id)sender;
- (IBAction)showHideLogView:(id)sender;
- (IBAction)showHideEventsView:(id)sender;
- (IBAction)showHideRecordingsView:(id)sender;

- (void)setRunData:(BRHRunData *)runData;

@end
