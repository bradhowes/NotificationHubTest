// BRHHistogram.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

extern NSString *BRHHistogramLastBinKey;
extern NSString *BRHHistogramMaxBinCountKey;

@interface BRHHistogram : NSObject <NSCoding>

@property (assign, nonatomic) NSUInteger lastBin;
@property (readonly, nonatomic) NSNumber *maxBinCount;

+ (instancetype)histogramWithLastBin:(NSUInteger)lastBin;

- (instancetype)initWithLastBin:(NSUInteger)lastBin;

- (NSArray *)bins;

- (NSNumber *)binAtIndex:(NSUInteger)index;

- (NSUInteger)binIndexFor:(double)value;

- (NSUInteger)addValue:(double)value;

- (void)addValues:(NSArray *)array;

- (void)clear;

@end
