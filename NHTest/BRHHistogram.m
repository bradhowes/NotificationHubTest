// BRHHistogram.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHHistogram.h"
#import "BRHLatencySample.h"

@interface BRHHistogram ()
@property (strong, nonatomic) NSMutableArray *bins;
@property (assign, nonatomic) NSUInteger maxBin;
@property (readwrite, strong, nonatomic) NSNumber *maxCount;

- (void)makeBins:(NSUInteger)lastBin;

@end

@implementation BRHHistogram

+ (instancetype)histogramWithLastBin:(NSUInteger)lastBin
{
    return [[BRHHistogram alloc] initWithLastBin:lastBin];
}

- (instancetype)initWithLastBin:(NSUInteger)lastBin
{
    if (self = [super init]) {
        [self makeBins:lastBin];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (! self) {
        return nil;
    }
    
    _bins = [decoder decodeObjectForKey:@"bins"];
    _lastBin = _bins.count - 1;
    _maxBin = 0;
    _maxCount = nil;

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.bins forKey:@"bins"];
}

- (void)makeBins:(NSUInteger)lastBin
{
    _lastBin = lastBin;
    _bins = [NSMutableArray arrayWithCapacity:lastBin];
    NSUInteger counter = _lastBin + 1;
    while (counter-- > 0) {
        [_bins addObject:[NSNumber numberWithInt:0]];
    }
    _maxBin = 0;
    _maxCount = 0;
}

static NSString *BRHHistogramLastBinKey = @"lastBin";

- (void)setLastBin:(NSUInteger)lastBin
{
    if (_lastBin != lastBin) {
        [self willChangeValueForKey:BRHHistogramLastBinKey];
        [self makeBins:lastBin];
        [self didChangeValueForKey:BRHHistogramLastBinKey];
    }
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
    return MAX(MIN((NSInteger)floor(value), _lastBin), 0);
}

- (NSUInteger)addValue:(double)value
{
    NSUInteger bin = [self binIndexFor:value];
    [_bins replaceObjectAtIndex:bin withObject:[NSNumber numberWithInteger:[[_bins objectAtIndex:bin] integerValue] + 1]];
    if (bin == _maxBin || [[_bins objectAtIndex:_maxBin] integerValue] != [[_bins objectAtIndex:bin] integerValue]) {
        _maxBin = bin;
        [self willChangeValueForKey:@"maxCount"];
        _maxCount = [_bins objectAtIndex:bin];
        [self didChangeValueForKey:@"maxCount"];
    }

    return bin;
}

- (void)addValues:(NSArray *)array
{
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL* stop)
    {
        BRHLatencySample *sample = obj;
        [self addValue:[sample.latency doubleValue]];
    }];
}

- (void)clear
{
    _maxCount = 0;
    for (NSUInteger index = 0; index < _bins.count; ++index) {
        [_bins replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:0]];
    }
}

- (NSUInteger)max
{
    NSNumber *found = nil;
    
    for (NSNumber* number in _bins) {
        if (found == nil || [found compare:number] == NSOrderedAscending) {
            found = number;
        }
    }
    
    return found ? [found unsignedIntegerValue] : 0;
}

@end
