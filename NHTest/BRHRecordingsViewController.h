// BRHRecordingsViewController.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

@class BRHDropboxUploader;

@interface BRHRecordingsViewController : UITableViewController

@property (strong, nonatomic) UIBarButtonItem *buttonItem;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) BRHDropboxUploader *dropboxUploader;

@end
