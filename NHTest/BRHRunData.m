// BRHRunData.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <math.h>

#import "BRHEventLog.h"
#import "BRHHistogram.h"
#import "BRHLatencySample.h"
#import "BRHRunData.h"
#import "BRHUserSettings.h"

static void* kKVOContext = &kKVOContext;

NSString *BRHRunDataNewDataNotification = @"BRHRunDataNewDataNotification";

@interface BRHRunData ()

@property (strong, nonatomic) NSMutableArray *orderedSamples;
@property (assign, readwrite, nonatomic) BOOL running;

@end

@implementation BRHRunData

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self) {
        BRHUserSettings *settings = [BRHUserSettings userSettings];
        _name = name;
        _startTime = nil;
        _bins = [BRHHistogram histogramWithLastBin:settings.maxHistogramBin];
        _missing = [NSMutableArray arrayWithCapacity:10];
        _samples = [NSMutableArray arrayWithCapacity:1000];
        _orderedSamples = [NSMutableArray arrayWithCapacity:1000];
        _emitInterval = [NSNumber numberWithUnsignedInteger:settings.emitInterval];
        _running = NO;

        [settings addObserver:self forKeyPath:@"maxHistogramBinSetting" options:NSKeyValueObservingOptionNew context:kKVOContext];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (! self) {
        return nil;
    }

    self.name = [decoder decodeObjectForKey:@"name"];
    self.startTime = [decoder decodeObjectForKey:@"startTime"];
    self.bins = [decoder decodeObjectForKey:@"bins"];
    self.missing = [decoder decodeObjectForKey:@"missing"];
    self.samples = [decoder decodeObjectForKey:@"samples"];
    self.emitInterval = [decoder decodeObjectForKey:@"emitInterval"];
    self.orderedSamples = nil;
    self.running = NO;

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.startTime forKey:@"startTime"];
    [encoder encodeObject:self.bins forKey:@"bins"];
    [encoder encodeObject:self.samples forKey:@"missing"];
    [encoder encodeObject:self.samples forKey:@"samples"];
    [encoder encodeObject:self.emitInterval forKey:@"emitInterval"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kKVOContext) {
        if (! self.running) {
            BRHUserSettings *settings = [BRHUserSettings userSettings];
            if ([keyPath isEqualToString:@"maxHistogramBinSetting"]) {
                self.bins.lastBin = settings.maxHistogramBin;
                [self.bins clear];
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)start
{
    self.running = YES;
    self.startTime = [NSDate date];

    BRHUserSettings *settings = [BRHUserSettings userSettings];
    self.emitInterval = [NSNumber numberWithUnsignedInteger:settings.emitInterval];
    self.bins.lastBin = settings.maxHistogramBin;

    [self.bins clear];
    [self.missing removeAllObjects];
    [self.samples removeAllObjects];
    [self.orderedSamples removeAllObjects];
}

- (void)stop
{
    self.running = NO;
}

- (BRHLatencySample *)min
{
    return [self.orderedSamples firstObject];
}

- (BRHLatencySample *)max
{
    return [self.orderedSamples lastObject];
}

- (BRHLatencySample *)orderedSampleAtIndex:(NSUInteger )index
{
    return self.orderedSamples[index];
}

- (void)recordLatency:(BRHLatencySample *)sample
{
    NSUInteger numLatencies = self.samples.count;
    NSUInteger missingCount = sample.identifier.integerValue - numLatencies;
    BRHLatencySample *prev = [self.samples lastObject];
    
    if (numLatencies == 0) {
        missingCount = 0;
    }
    else if (missingCount > 0) {
        NSUInteger missingIdentifier = numLatencies;
        NSDate *emissionTime = prev.emissionTime;

        // Fill in missing notifications with bogus data
        //
        while (missingIdentifier < sample.identifier.integerValue) {
            BRHLatencySample *missing = [BRHLatencySample new];
            missing.identifier = [NSNumber numberWithInteger:missingIdentifier];
            [BRHEventLog add:@"missingNotification", missing.identifier, nil];
            missing.latency = [NSNumber numberWithDouble:0.0];
            emissionTime = [emissionTime dateByAddingTimeInterval:self.emitInterval.integerValue];
            missing.emissionTime = emissionTime;
            missing.arrivalTime = nil;
            [self.missing addObject:missing];
            ++missingIdentifier;
        }
    }

    double prevAverage = prev ? prev.average.doubleValue : 0.0;
    double latency = sample.latency.doubleValue;
    sample.average = [NSNumber numberWithDouble:(latency + numLatencies * prevAverage) / (numLatencies + 1)];

    // Locate the proper position to insert the new value to keep the ordered array sorted
    //
    NSRange range = NSMakeRange(0, self.orderedSamples.count);
    NSUInteger index = [self.orderedSamples indexOfObject:sample inSortedRange:range options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];

    // Add new stat to all of the containers
    //
    [self.orderedSamples insertObject:sample atIndex:index];
    [self.samples addObject:sample];

    NSUInteger bin = [self.bins addValue:latency];
    ++numLatencies;

    // Calculate median value from the sorted container
    //
    index = numLatencies / 2;
    double median = [self orderedSampleAtIndex:index].latency.doubleValue;
    if (numLatencies % 2 == 0) {
        median = (median + [self orderedSampleAtIndex:index - 1].latency.doubleValue) / 2.0;
    }

    sample.median = [NSNumber numberWithDouble:median];

    // Alert interested parties that there is new data
    //
    [[NSNotificationCenter defaultCenter] postNotificationName:BRHRunDataNewDataNotification
                                                        object:self
                                                      userInfo:@{@"newSampleIndex": @(numLatencies - 1),
                                                                 @"newSampleCount": @(1),
                                                                 @"missingIndex": @(self.missing.count- 1),
                                                                 @"missingCount": @(missingCount),
                                                                 @"bin":@(bin)}];
}

@end
