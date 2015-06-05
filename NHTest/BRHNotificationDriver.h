// BRHNotificationDriver.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

@class BRHLatencySample;

typedef void (^BRHNotificationDriverFetchCompletionBlock)(BOOL success, BOOL hasData);

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

/*!
 * @brief Start the driver and begin recording notification arrivals.
 */
- (BOOL)startEmitting:(NSNumber *)emitInterval;

/*!
 * @brief Stop the driver.
 */
- (void)stopEmitting;

- (BRHLatencySample *)receivedNotification:(NSDictionary *)userInfo at:(NSDate *)when
      fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)calculateLatency:(BRHLatencySample *)sample;

- (void)fetchUpdate:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)updateWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end
