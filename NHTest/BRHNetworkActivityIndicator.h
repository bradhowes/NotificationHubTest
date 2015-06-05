// BRHNetworkActivityIndicator.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

/*!
 * @brief Dirt-simple class that manages the network activity indicator in the status bar.
 *
 * General usage is to create instances in code where there is network activity taking place.
 * When the activity stops, clear out the instance. When the number of instances is greater
 * than zero, the network activity indicator will spin. When the count is zero, the spinning
 * should stop and the activity indicator will go away.
 */
@interface BRHNetworkActivityIndicator : NSObject

@end
