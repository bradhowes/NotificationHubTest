// BRHLatencySample.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

extern NSString *BRHLatencySampleIdentifierKey;
extern NSString *BRHLatencySampleLatencyKey;
extern NSString *BRHLatencySampleEmissionTimeKey;
extern NSString *BRHLatencySampleArrivalTimeKey;
extern NSString *BRHLatencySampleMedianKey;
extern NSString *BRHLatencySampleAverageKey;

/*!
 *    @brief  Representation of one push notification arrival
 */
@interface BRHLatencySample : NSObject <NSCoding>

@property (strong, nonatomic) NSNumber *identifier;
@property (strong, nonatomic) NSNumber *latency;
@property (strong, nonatomic) NSDate *emissionTime;
@property (strong, nonatomic) NSDate *arrivalTime;
@property (strong, nonatomic) NSNumber *median;
@property (strong, nonatomic) NSNumber *average;

- (BOOL)isDuplicateOf:(BRHLatencySample *)other;

@end
