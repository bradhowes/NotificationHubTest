// BRHRunData.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

extern NSString *BRHRunDataNewDataNotification;

/*!
 @brief Description of the new data added to BRHRunData.
 
 An instance of this class is found in the NSNotification object of the BRHRunDataNewDataNotification notification
 handler.
 
 */
@interface BRHRunDataNotificationInfo : NSObject

/*!
 @brief Where in the BRHRunData samples container does the new data start
 */
@property (assign, nonatomic) NSUInteger sampleIndex;

/*!
 @brief The number of new entries in BRHRunData samples
 */
@property (assign, nonatomic) NSUInteger sampleCount;

/*!
 @brief Where in the BRHRunData missing container does the new data start
 */
@property (assign, nonatomic) NSUInteger missingIndex;

/*!
 @brief The number of new entries in BRHRuData missing.
 */
@property (assign, nonatomic) NSUInteger missingCount;

/*!
 @brief The bin in BRHRunData bins that increased in count.
 */
@property (assign, nonatomic) NSUInteger binIndex;

@end

@class BRHHistogram;
@class BRHLatencySample;

/*!
 * @brief Container for the results of a run.
 */
@interface BRHRunData : NSObject <NSCoding>

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
