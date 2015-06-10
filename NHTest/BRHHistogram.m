// BRHHistogram.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHHistogram.h"
#import "BRHLatencySample.h"

@interface BRHHistogram ()

@property (strong, nonatomic) NSMutableArray *bins;
@property (assign, readwrite, nonatomic) NSNumber *maxBinCount;

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

    _maxBinCount = [NSNumber numberWithInteger:0];

    for (NSUInteger binIndex = 0; binIndex < _bins.count; ++binIndex) {
        NSNumber *bin = _bins[binIndex];
        if (bin.unsignedIntegerValue > _maxBinCount.unsignedIntegerValue) {
            _maxBinCount = bin;
        }
    }

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

    _maxBinCount = [NSNumber numberWithInteger:0];
}

NSString *BRHHistogramLastBinKey = @"BRHHistogramLastBinKey";

- (void)setLastBin:(NSUInteger)lastBin
{
    if (_lastBin != lastBin) {
        [self willChangeValueForKey:BRHHistogramLastBinKey];
        [self makeBins:lastBin];
        [self didChangeValueForKey:BRHHistogramLastBinKey];
    }
}

- (void)setMaxBinCount:(NSNumber *)maxBinCount
{
    [self willChangeValueForKey:BRHHistogramMaxBinCountKey];
    _maxBinCount = maxBinCount;
    [self didChangeValueForKey:BRHHistogramMaxBinCountKey];
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

NSString *BRHHistogramMaxBinCountKey = @"BRHHistogramMaxBinCountKey";

- (NSUInteger)addValue:(double)value
{
    NSUInteger binIndex = [self binIndexFor:value];
    NSNumber *bin = _bins[binIndex];
    bin = [NSNumber numberWithInteger:bin.unsignedIntegerValue + 1];
    _bins[binIndex] = bin;
    if (_maxBinCount.unsignedIntegerValue < bin.unsignedIntegerValue) {
        self.maxBinCount = bin;
    }
    return binIndex;
}

- (void)addValues:(NSArray *)array
{
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL* stop)
    {
        BRHLatencySample *sample = obj;
        [self addValue:sample.latency.doubleValue];
    }];
}

- (void)clear
{
    for (NSUInteger index = 0; index < _bins.count; ++index) {
        [_bins replaceObjectAtIndex:index withObject:[NSNumber numberWithInteger:0]];
    }

    self.maxBinCount = _bins[0];
}

- (NSUInteger)max
{
    NSNumber *found = _bins[0];
    for (NSNumber* number in _bins) {
        if ([found compare:number] == NSOrderedAscending) {
            found = number;
        }
    }

    return found ? found.unsignedIntegerValue : 0;
}

@end
