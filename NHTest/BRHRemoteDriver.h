//
//  BRHRemoteDriver.h
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import "BRHNotificationDriver.h"

/*!
 @brief Derivation of BRHNotificationDriver that talks to a remote 'emitter' service.
 
 At start time, the driver registers with the remote service, sending it the APNs device token to use for notifications
 and the emitInterval value for the frequency of push notification emissions. When a push notification arrives at the 
 device, the app asks for data related to the notification. Finally, at stop time, the app unregisters from the service.
 
 @note this is the only driver that runs while the app is in the background.
 */
@interface BRHRemoteDriver : BRHNotificationDriver

/*!
 @brief An estimate of the clock offset between the remote service and the device.
 
 The driver will use this value to adjust latency calculations between the service and device timestamps.
 */
@property (assign, nonatomic) double deviceServerDelta;

@end
