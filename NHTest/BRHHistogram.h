//
//  BRHHistogram.h
//  NHTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHHistogram : NSObject

+ (instancetype)histogramWithSize:(NSUInteger)size;

- (instancetype)initWithSize:(NSUInteger)size;

- (NSUInteger)count;

- (NSArray *)bins;

- (NSNumber *)binAtIndex:(NSUInteger)index;

- (NSUInteger)binIndexFor:(double)value;

- (NSUInteger)addValue:(double)value;

- (void)addValues:(NSArray *)array;

- (void)clear;

- (NSUInteger)max;

@end
