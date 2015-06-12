// BRHNotificationDriver.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHNotificationDriver.h"

/*!
 * @brief Derivation of BRHNotificationDriver that generates synthetic notifications.

 @note this is only useful for testing out notification code flow when the app is in the foreground since there is
 currently no way to run a timer that will fire in the background.

 */
@interface BRHSimDriver : BRHNotificationDriver

@end
