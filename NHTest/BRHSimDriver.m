// BRHNotificationDriver.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <math.h>

#import "BRHAppDelegate.h"
#import "BRHLatencySample.h"
#import "BRHLogger.h"
#import "BRHSimDriver.h"

@interface BRHSimDriver ()

@property (assign, nonatomic) NSUInteger notificationSequenceId;
@property (strong, nonatomic) NSTimer *emitter;
@property (assign, nonatomic) NSTimeInterval emissionTime;

- (void)emitNotification;
- (void)emitterFired:(NSTimer *)timer;

@end

@implementation BRHSimDriver

- (instancetype)init
{
    self = [super init];
    if (self) {
        _notificationSequenceId = 0;
        _emitter = nil;
    }

    return self;
}

- (void)startEmitting:(NSNumber *)emitInterval completionBlock:(BRHNotificationDriverStartCompletionBlock )completionBlock
{
    [super startEmitting:emitInterval];
    self.emissionTime = [[NSDate date] timeIntervalSince1970];
    self.notificationSequenceId = 0;
    NSTimeInterval when = 1.0;
    self.emitter = [NSTimer scheduledTimerWithTimeInterval:when target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];

    completionBlock(YES);
}

- (double)randomValue
{
    return arc4random() / (double)UINT32_MAX;
}

- (NSTimeInterval)calculateLatency:(BRHLatencySample *)sample
{
    return self.randomValue * 5.0 + 0.12345;;
}

- (void)stopEmitting:(BRHNotificationDriverStopCompletionBlock )completionBlock
{
    if (self.emitter) {
        [self.emitter invalidate];
        self.emitter = nil;
    }

    [super stopEmitting];
    completionBlock();
}

- (void)emitterFired:(NSTimer *)timer
{
    [self emitNotification];
    NSTimeInterval when = 1.0;
    self.emitter = [NSTimer scheduledTimerWithTimeInterval:when target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];
}

- (void)emitNotification
{
    UIApplication *app = [UIApplication sharedApplication];

    NSNumber *identifier = [NSNumber numberWithInteger:self.notificationSequenceId];
    NSNumber *when = [NSNumber numberWithDouble:self.emissionTime];
    NSDictionary *notification = @{@"id": identifier, @"when": when};

    self.notificationSequenceId += 1;
    self.emissionTime += self.emitInterval.integerValue;

    if (self.randomValue < 0.2) {
        NSLog(@"creating missing notification");
        return;
    }

    [app.delegate application:app didReceiveRemoteNotification:notification fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        [BRHLogger add:@"fetchCompletionHandler: %lu", (unsigned long)result];
    }];
}

@end
