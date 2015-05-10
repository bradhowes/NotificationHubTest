//
//  BRHLogger.h
//  NotificationHubTest
//
//  Created by Brad Howes on 1/3/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *BRHLogContentsChanged;

@interface BRHLogger : NSObject

@property (nonatomic, strong) NSURL *logPath;

+ (instancetype) sharedInstance;
+ (NSString *) add:(NSString*)format, ...;

- (void)clear;
- (NSString*)contents;
- (void)save;

@end
