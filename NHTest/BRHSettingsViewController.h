//
//  BRHSettingsViewController.h
//  NHTest
//
//  Created by Brad Howes on 4/12/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "InAppSettingsKit/IASKAppSettingsViewController.h"

/*!
 * @brief Adaptation of the IASKAppSettingsViewController that shows setting values from our BRHUSerSettings instance.
 */
@interface BRHSettingsViewController : IASKAppSettingsViewController <IASKSettingsDelegate>

@end
