//
//  BRHSettingsViewController.h
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "InAppSettingsKit/IASKAppSettingsViewController.h"

@class BRHMainViewController;

/*!
 * @brief Adaptation of the IASKAppSettingsViewController that shows setting values from our BRHUSerSettings instance.
 */
@interface BRHSettingsViewDelegate : NSObject <IASKSettingsDelegate, UITextFieldDelegate>

@property (strong, nonatomic) BRHMainViewController *mainWindowController;
@property (strong, nonatomic) IASKAppSettingsViewController* settingsViewController;

@end
