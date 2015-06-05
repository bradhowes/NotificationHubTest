//
//  BRHSettingsViewController.m
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHSettingsViewController.h"
#import "BRHAppDelegate.h"
#import "BRHNotificationDriver.h"
#import "BRHUserSettings.h"

@implementation BRHSettingsViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.delegate = self;
        // Custom initialization
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [BRHUserSettings userSettings].blockingNotifications = YES;
}

- (IBAction)dismiss:(id)sender {

    // NOTE: order here is a bit magical. The key is to get the latest values into NSUserDefaults and then
    // flag the changes with KVO updates.
    //
    [self dismissViewControllerAnimated:YES completion:nil];
    BRHUserSettings *settings = [BRHUserSettings userSettings];
    settings.blockingNotifications = NO;

    // This is supposed to update settings from InAppSettingsKit view
    //
    [super dismiss:sender];
    
    // But this seems to do the trick.
    //
    [settings readPreferences];
}

@end
