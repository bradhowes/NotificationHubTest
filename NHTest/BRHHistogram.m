//
//  BRHHistogram.m
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import "BRHHistogram.h"
#import "BRHLatencyValue.h"

@interface BRHHistogram ()
@property (nonatomic, strong) NSMutableArray *bins;
@end

@implementation BRHHistogram

+ (instancetype)histogramWithSize:(NSUInteger)size
{
    return [[BRHHistogram alloc] initWithSize:size];
}

- (instancetype)initWithSize:(NSUInteger)size
{
    if (! (self = [super init])) return self;
    _bins = [NSMutableArray arrayWithCapacity:size];
    while (size-- > 0) {
        [_bins addObject:[NSNumber numberWithInt:0]];
    }

    return self;
}

- (NSUInteger)count
{
    return _bins.count;
}

- (NSArray *)bins
{
    return _bins;
}

- (NSNumber *)binAtIndex:(NSUInteger)index
{
    return [_bins objectAtIndex:index];
}

- (NSUInteger)binIndexFor:(double)value
{
    return MAX(MIN((NSInteger)floor(value), _bins.count - 1), 0);
}

- (NSUInteger)addValue:(double)value
{
    NSUInteger index = [self binIndexFor:value];
    [_bins replaceObjectAtIndex:index withObject:[NSNumber numberWithInteger:[[_bins objectAtIndex:index] integerValue] + 1]];
    return index;
}

- (void)addValues:(NSArray *)array
{
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL* stop)
    {
        BRHLatencyValue *value = obj;
        [self addValue:[value.value doubleValue]];
    }];
}

- (void)clear
{
    for (NSUInteger index = 0; index < _bins.count; ++index) {
        [_bins replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:0]];
    }
}

@end
