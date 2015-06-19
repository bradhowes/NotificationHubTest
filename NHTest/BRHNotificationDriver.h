// BRHNotificationDriver.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

@class BRHLatencySample;

typedef void (^BRHNotificationDriverStartCompletionBlock)(BOOL isRunning);
typedef void (^BRHNotificationDriverStopCompletionBlock)();

/*!
 @brief Base class for drivers that generate notifications for tests.
 */
@interface BRHNotificationDriver : NSObject

/*!
 @brief APNs device token for this device.
 */
@property (strong, nonatomic) NSData *deviceToken;

/*!
 @brief The number of seconds between push notifications sent to the device
 */
@property (strong, nonatomic) NSNumber *emitInterval;

/*!
 @brief The last notification identifier that was emitted. Used for detecting duplicate notifications.
 */
@property (strong, nonatomic) NSNumber *lastIdentifier;

/*!
 @brief Start the driver and start receiving notifications. 
 
 Derived classes should invoke this from their startEmitting:completionBlock: method.
 
 @param emitInterval the number of seconds between notifications
 */
- (void)startEmitting:(NSNumber *)emitInterval;

/*!
 @brief Start the driver and start receiving notifications.
 
 @note derived classes must define this
 
 @param emitInterval the number of seconds between notifications
 @param completionBlock the block to invoke when the starting is complete
 */
- (void)startEmitting:(NSNumber *)emitInterval completionBlock:(BRHNotificationDriverStartCompletionBlock )completionBlock;

/*!
 * @brief Stop the driver.
 */
- (void)stopEmitting;

- (BRHLatencySample *)receivedNotification:(NSDictionary *)userInfo at:(NSDate *)when
      fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (NSTimeInterval)calculateLatency:(BRHLatencySample *)sample;

- (void)fetchUpdate:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end
