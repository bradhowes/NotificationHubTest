// BRHNotificationDriver.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

@class BRHLatencySample;

typedef void (^BRHNotificationDriverStartCompletionBlock)(BOOL isRunning);
typedef void (^BRHNotificationDriverStopCompletionBlock)();

/*!
 * @brief Base class for drivers that generate notifications for tests.
 */
@interface BRHNotificationDriver : NSObject

/*!
 * @brief APNs device token for this device.
 */
@property (strong, nonatomic) NSData *deviceToken;

/*!
 * @brief The number of seconds between push notifications sent to the device
 */
@property (strong, nonatomic) NSNumber *emitInterval;

@property (strong, nonatomic) NSNumber *lastIdentifier;

- (void)startEmitting:(NSNumber *)emitInterval;

/*!
 * @brief Start the driver and begin recording notification arrivals.
 */
- (void)startEmitting:(NSNumber *)emitInterval completionBlock:(BRHNotificationDriverStartCompletionBlock )completionBlock;

/*!
 * @brief Stop the driver.
 */
- (void)stopEmitting;

- (void)stopEmitting:(BRHNotificationDriverStopCompletionBlock )completionBlock;

- (BRHLatencySample *)receivedNotification:(NSDictionary *)userInfo at:(NSDate *)when
      fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (NSTimeInterval)calculateLatency:(BRHLatencySample *)sample;

- (void)fetchUpdate:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end
