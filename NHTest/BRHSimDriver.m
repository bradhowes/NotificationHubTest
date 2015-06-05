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

- (BOOL)startEmitting:(NSNumber *)emitInterval
{
    if (! [super startEmitting:emitInterval]) return NO;

    self.notificationSequenceId = 0;
    NSTimeInterval when = 1.0;
    self.emitter = [NSTimer scheduledTimerWithTimeInterval:when target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];

    return YES;
}

- (void)stopEmitting
{
    if (self.emitter) {
        [self.emitter invalidate];
        self.emitter = nil;
    }

    [super stopEmitting];
}

- (double)gaussian1
{
    double w, x1;
    do {
        x1 = 2.0 * arc4random() / UINT32_MAX - 1.0; // uniform distribution from -1 to +1
        double x2 = 2.0 * arc4random() / UINT32_MAX - 1.0;
        w = x1 * x1 + x2 * x2;
    } while ( w >= 1.0 );
    
    w = sqrt((-2.0 * log(w)) / w);
    
    double y = x1 * w;
    
    return y;
}

- (double)gaussian2
{
    double u1 = (double)arc4random() / UINT32_MAX; // uniform distribution from 0-1
    double u2 = (double)arc4random() / UINT32_MAX; // uniform distribution from 0-1
    double f1 = sqrt(-2 * log(u1));
    double f2 = 2 * M_PI * u2;
    double g = f1 * cos(f2); // gaussian distribution
    return g;
}

- (double)pseudoGaussian
{
    double s = 0.0;
    for (int count = 0; count < 6; ++count) {
        s += arc4random_uniform(100) + 1.0;  // 6 - 600
    }
    
    return s / 10.0; // .6 - 60.0
}

- (double)ramp
{
    return self.notificationSequenceId % 60 * 1.0;
}

- (void)emitterFired:(NSTimer *)timer
{
    [self emitNotification];
    NSTimeInterval emitInterval = self.emitInterval.intValue;
    self.emitter = [NSTimer scheduledTimerWithTimeInterval:emitInterval target:self selector:@selector(emitterFired:) userInfo:nil repeats:NO];
}

- (void)emitNotification
{
    UIApplication *app = [UIApplication sharedApplication];

    NSNumber *identifier = [NSNumber numberWithInteger:self.notificationSequenceId];
    self.notificationSequenceId += 1;

    [app.delegate application:app didReceiveRemoteNotification:@{@"id": identifier,
                                                                 @"when":[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]]}
       fetchCompletionHandler:^(UIBackgroundFetchResult result) {
           [BRHLogger add:@"fetchCompletionHandler: %lu", (unsigned long)result];
       }];
}

@end
