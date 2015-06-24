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
    [self doesNotRecognizeSelector:_cmd];
}

- (void)stopEmitting
{
    [BRHLogger add:@"driver stopping"];
    [BRHEventLog add:@"driverStop",nil];
}

- (BRHLatencySample *)receivedNotification:(NSDictionary *)notification at:(NSDate *)when fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [BRHLogger add: @"receivedNotification - %@", notification];
    NSNumber *identifier = notification[@"id"];
    
    BRHLatencySample *sample = [BRHLatencySample new];
    sample.identifier = identifier;
    NSNumber *emissionTime = notification[@"when"];
    sample.emissionTime = [NSDate dateWithTimeIntervalSince1970:emissionTime.doubleValue];
    sample.arrivalTime = when;
    sample.latency = [NSNumber numberWithDouble:[self calculateLatency:sample]];
    [BRHLogger add:@"latency: %@", sample.latency];

    if (self.lastIdentifier) {
        NSString *tag = nil;
        if (self.lastIdentifier.integerValue == identifier.integerValue) {
            tag = @"duplicate";
        }
        else if (self.lastIdentifier.integerValue > identifier.integerValue) {
            tag = @"old";
        }
        
        if (tag) {
            [BRHLogger add:@"%@ notification - %@", tag, identifier];
            [BRHEventLog add:[tag stringByAppendingString:@"Notification"],sample.identifier, sample.emissionTime, sample.arrivalTime, sample.latency, nil];
            completionHandler(UIBackgroundFetchResultNoData);
            return nil;
        }
    }

    [BRHEventLog add:@"receivedNotification",sample.identifier, sample.emissionTime, sample.arrivalTime, sample.latency, nil];
    self.lastIdentifier = identifier;
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
