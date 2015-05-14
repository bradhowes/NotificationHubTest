//
//  BRHNotificationDriver.h
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *BRHNotificationDriverReceivedNotification;
extern NSString *BRHNotificationDriverRunningStateChanged;

@class BRHHistogram;
@class BRHLatencyValue;
@class BRHRemoteDriver;

typedef void (^BRHNotificationDriverFetchCompletionHandler)(BOOL success, NSString* msg);
typedef void (^BRHNotificationDriverUpdateCompletionHandler)(BOOL success, BOOL updated);

@interface BRHNotificationDriver : NSObject

@property (nonatomic, assign) BOOL sim;
@property (nonatomic, strong) NSData *deviceToken;
@property (nonatomic, strong) NSMutableArray *latencies;
@property (nonatomic, strong) BRHHistogram *bins;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) BRHRemoteDriver* remoteDriver;
@property (nonatomic, assign) NSTimeInterval emitInterval;
@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (void)reset;
- (void)start;
- (void)stop;

- (BRHLatencyValue *)min;
- (BRHLatencyValue *)max;

- (void)emitNotification;
- (void)received:(NSNumber *)identifier timeOfArrival:(NSDate *)timeOfArrival contents:(NSDictionary *)contents;
- (void)editingSettings:(BOOL)state;

@end
