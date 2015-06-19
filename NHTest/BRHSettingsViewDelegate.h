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

/*!
 @brief The main view controller that manages top-level views
 */
@property (strong, nonatomic) BRHMainViewController *mainWindowController;

/*!
 @brief The settings view that we are the delegate for
 */
@property (strong, nonatomic) IASKAppSettingsViewController* settingsViewController;

@end
