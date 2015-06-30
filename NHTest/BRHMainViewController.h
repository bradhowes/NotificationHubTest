// BRHMainController.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

@class BRHDropboxUploader;
@class BRHLatencyHistogramGraph;
@class BRHLatencyByTimeGraph;
@class BRHRecordingInfo;
@class BRHRecordingsViewController;
@class BRHSettingsViewDelegate;
@class BRHRunData;
@class IASKAppSettingsViewController;

/*!
 @brief The top-level view controller for the application.
 
 The main view consists of two graphs stacked vertically. The top graph shows the notification arrival latencies over
 time. The lower graph shows a histogram of latency counts with 1-second quantization.
 
 There are three overlay views that, when made active, will obscure the lower graph. These are:
 
 - log view showing the log trace for the application
 - event view containing lines of comma-separated values (for exporting as a CSV file)
 - recordings view depicting the past recordings of experiments
 
 These overlay views are controlled by buttons in a toolbar found at the bottom of the screen.
 
 */
@interface BRHMainViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *stopButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *recordingsButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsButton;

@property (strong, nonatomic) IBOutlet BRHLatencyByTimeGraph *latencyPlot;
@property (strong, nonatomic) IBOutlet BRHLatencyHistogramGraph *countBars;
@property (strong, nonatomic) IBOutlet UITextView *logView;
@property (strong, nonatomic) IBOutlet UITextView *eventsView;
@property (strong, nonatomic) IBOutlet UIView *recordingsView;

@property (strong, nonatomic) BRHRecordingsViewController *recordingsViewController;
@property (strong, nonatomic) IASKAppSettingsViewController *settingsViewController;
@property (strong, nonatomic) BRHSettingsViewDelegate *settingsViewDelegate;
@property (strong, nonatomic) BRHDropboxUploader *dropboxUploader;

@property (strong, nonatomic) BRHRecordingInfo *recordingInfo;

- (IBAction)startStop:(id)sender;
- (IBAction)showHideLogView:(id)sender;
- (IBAction)showHideEventsView:(id)sender;
- (IBAction)showHideRecordingsView:(id)sender;
- (IBAction)showSettings:(id)sender;

- (void)start;
- (void)stop;
- (void)shareRecording:(BRHRecordingInfo *)recordingInfo atButton:(UIButton *)button;

@end
