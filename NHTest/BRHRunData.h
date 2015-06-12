// BRHRunData.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

extern NSString *BRHRunDataNewDataNotification;

@interface BRHRunDataNotificationInfo : NSObject

@property (assign, nonatomic) NSUInteger sampleIndex;
@property (assign, nonatomic) NSUInteger sampleCount;
@property (assign, nonatomic) NSUInteger missingIndex;
@property (assign, nonatomic) NSUInteger missingCount;
@property (assign, nonatomic) NSUInteger binIndex;

@end

@class BRHHistogram;
@class BRHLatencySample;

/*!
 * @brief Container for the results of a test run.
 */
@interface BRHRunData : NSObject <NSCoding>

@property (strong, nonatomic) NSDate *startTime;

@property (strong, nonatomic) NSString *name;

@property (strong, nonatomic) NSMutableArray *missing;

/*!
 * @brief Array of BRHLatencyValue objects for received push notifications.
 */
@property (strong, nonatomic) NSMutableArray *samples;

/*!
 * @brief Histogram of latencies for received push notifications.
 */
@property (strong, nonatomic) BRHHistogram *bins;

/*!
 * @brief Value of the user setting by the same name at the time beginRun was invoked.
 */
@property (strong, nonatomic) NSNumber *emitInterval;

@property (assign, readonly, nonatomic) BOOL running;

- (instancetype)initWithName:(NSString *)name;

/*!
 * @brief Clear all data and record the start time of the run
 */
- (void)start;

- (void)stop;

/*!
 * @brief Obtain minimum latency value seen so far
 *
 * @return BRHLatencyValue object with the lowest latency value
 */
- (BRHLatencySample *)min;

/*!
 * @brief Obtain the largest latency value seen so far
 *
 * @return BRHLatencyValue object with the highest latency value
 */
- (BRHLatencySample *)max;

/*!
 * @brief Record the receipt of a push notification
 *
 * @param latency the delta between when the notification was sent and when the device received it
 * @param identifier the unique identifier for the notification
 */
- (void)recordLatency:(BRHLatencySample *)latency;

@end
