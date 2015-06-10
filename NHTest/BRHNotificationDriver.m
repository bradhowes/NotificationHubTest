// BRHNotificationDriver.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHEventLog.h"
#import "BRHLogger.h"
#import "BRHLatencySample.h"
#import "BRHNotificationDriver.h"

@implementation BRHNotificationDriver

- (instancetype)init
{
    self = [super init];
    if (self) {
        _emitInterval = nil;
        _lastIdentifier = nil;
    }

    return self;
}

- (void)startEmitting:(NSNumber *)emitInterval
{
    [BRHLogger add:@"driver starting"];
    [BRHEventLog add:@"driverStart", emitInterval, nil];
    self.emitInterval = emitInterval;
}

- (void)startEmitting:(NSNumber *)emitInterval completionBlock:(BRHNotificationDriverStartCompletionBlock)completionBlock
{
    [self startEmitting:emitInterval];
    completionBlock(YES);
}

- (void)stopEmitting
{
    [BRHLogger add:@"driver stopping"];
    [BRHEventLog add:@"driverStop",nil];
}

- (void)stopEmitting:(BRHNotificationDriverStopCompletionBlock )completionBlock
{
    [self stopEmitting];
    completionBlock(YES);
}

- (BRHLatencySample *)receivedNotification:(NSDictionary *)notification at:(NSDate *)when fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add: @"receivedNotification - %@", notification];
    NSNumber *identifier = notification[@"id"];
    if (self.lastIdentifier && self.lastIdentifier.integerValue == identifier.integerValue) {
        [BRHEventLog add:@"duplicateNotification", identifier, nil];
        completionHandler(UIBackgroundFetchResultNoData);
        return nil;
    }

    self.lastIdentifier = identifier;
    BRHLatencySample *sample = [BRHLatencySample new];
    sample.identifier = identifier;
    NSNumber *emissionTime = notification[@"when"];
    sample.emissionTime = [NSDate dateWithTimeIntervalSince1970:emissionTime.doubleValue];
    sample.arrivalTime = when;

    sample.latency = [NSNumber numberWithDouble:[self calculateLatency:sample]];
    [BRHLogger add:@"latency: %@", sample.latency];
    [BRHEventLog add:@"receivedNotification",sample.identifier, sample.emissionTime, sample.arrivalTime, sample.latency, nil];
    [self fetchUpdate:notification fetchCompletionHandler:completionHandler];

    return sample;
}

- (void)fetchUpdate:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add:@"fetchUpdate - UIBackgroundFetchResultNoData"];
    completionHandler(UIBackgroundFetchResultNoData);
}

- (NSTimeInterval)calculateLatency:(BRHLatencySample *)sample
{
    return [sample.arrivalTime timeIntervalSinceDate:sample.emissionTime];
}

- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;
{
    completionHandler();
}

@end
