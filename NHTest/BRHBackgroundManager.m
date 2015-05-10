//
//  BRHBackgroundManager.m
//  NHTest
//
//  Created by Brad Howes on 2/11/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import "BRHBackgroundManager.h"

@interface BRHBackgroundManager ()

@property (nonatomic, assign) UIBackgroundTaskIdentifier task;

- (void)beginBackgroundMode:(NSNotification*)notification;

@end

@implementation BRHBackgroundManager

-(void)startTask
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]) {
        self->_isRunning = YES;
        self.task = UIBackgroundTaskInvalid;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(beginBackgroundMode:)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
}

- (void)beginBackgroundMode:(NSNotification *)notification
{
    UIApplication *app = [UIApplication sharedApplication];
    
    if ([app respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
        self.task = [app beginBackgroundTaskWithExpirationHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.task != UIBackgroundTaskInvalid) {
                    [app endBackgroundTask:self.task];
                    self.task = UIBackgroundTaskInvalid;
                }
            });
        }];
    }
}

-(void)endTask
{
    self->_isRunning = NO;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(endBackgroundTask:)]) {
        if (self.task != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:self.task];
            self.task = UIBackgroundTaskInvalid;
        }
    }
}

-(BOOL)isInBackground
{
    return self.isRunning && self.task != UIBackgroundTaskInvalid;
}

@end
