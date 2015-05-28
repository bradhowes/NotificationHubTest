//
//  BRHMainViewController.h
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@class BRHCountBars;
@class BRHLatencyPlot;

@interface BRHMainViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *playButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *stopButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *settingsButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *shareButton;

@property (nonatomic, strong) IBOutlet BRHLatencyPlot *latencyPlot;
@property (nonatomic, strong) IBOutlet BRHCountBars *countBars;
@property (nonatomic, strong) IBOutlet UITextView *events;
@property (nonatomic, strong) IBOutlet UITextView *log;
@property (nonatomic, strong) NSURL *runDirectory;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *logVerticalConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *eventsVerticalConstraint;

- (IBAction)startStop:(id)sender;
- (IBAction)showHideLogView:(id)sender;
- (IBAction)showHideEventsView:(id)sender;
- (IBAction)share:(id)sender;

@end
