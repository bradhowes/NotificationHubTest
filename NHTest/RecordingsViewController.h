// -*- Mode: ObjC -*-
//
// Copyright (C) 2011, Brad Howes. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RecordingInfo;

@interface RecordingsViewController : UITableViewController

- (void)updateFromSettings;

- (RecordingInfo*)startRecording;

- (void)stopRecording;

- (void)saveContext;

@end
