// BRHNotificationDriver.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHNotificationDriver.h"

/*!
 * @brief Derivation of BRHNotificationDriver that talks to APNs directly to send out notifications to the device.
 
 @note this is only useful for testing out notification code flow when the app is in the foreground since there is 
 currently no way to communicate to APNs while in the background.
 
 */
@interface BRHLoopNotificationDriver : BRHNotificationDriver

@end
