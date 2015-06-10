//
//  BRHSettingsViewController.h
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "InAppSettingsKit/IASKAppSettingsViewController.h"

@interface BRHSettingsViewController : IASKAppSettingsViewController <IASKSettingsDelegate>

- (IBAction)dismiss:(id)sender;

@end
