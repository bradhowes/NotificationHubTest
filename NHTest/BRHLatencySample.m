// BRHLatencyValue.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencySample.h"

NSString *BRHLatencySampleIdentifierKey = @"identifier";
NSString *BRHLatencySampleLatencyKey = @"latency";
NSString *BRHLatencySampleEmissionTimeKey = @"emissionTime";
NSString *BRHLatencySampleArrivalTimeKey = @"arrivalTime";
NSString *BRHLatencySampleMedianKey = @"median";
NSString *BRHLatencySampleAverageKey = @"average";

@implementation BRHLatencySample

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (! self) {
        return nil;
    }
    
    self.identifier = [decoder decodeObjectForKey:BRHLatencySampleIdentifierKey];
    self.latency = [decoder decodeObjectForKey:BRHLatencySampleLatencyKey];
    self.emissionTime = [decoder decodeObjectForKey:BRHLatencySampleEmissionTimeKey];
    self.arrivalTime = [decoder decodeObjectForKey:BRHLatencySampleArrivalTimeKey];
    self.median = [decoder decodeObjectForKey:BRHLatencySampleMedianKey];
    self.average = [decoder decodeObjectForKey:BRHLatencySampleAverageKey];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.identifier forKey:BRHLatencySampleIdentifierKey];
    [encoder encodeObject:self.latency forKey:BRHLatencySampleLatencyKey];
    [encoder encodeObject:self.emissionTime forKey:BRHLatencySampleEmissionTimeKey];
    [encoder encodeObject:self.arrivalTime forKey:BRHLatencySampleArrivalTimeKey];
    [encoder encodeObject:self.median forKey:BRHLatencySampleMedianKey];
    [encoder encodeObject:self.average forKey:BRHLatencySampleAverageKey];
}

- (NSComparisonResult)compare:(BRHLatencySample *)other
{
    return [self.latency compare:other.latency];
}

- (BOOL)isDuplicateOf:(BRHLatencySample *)other
{
    return other.identifier.integerValue == self.identifier.integerValue;
}

@end

