//
//  BRHRemoteDriver.h
//  NHTest
//
//  Created by Brad Howes on 2/13/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^BRHRemoteDriverFetchCompletionBlock)(BOOL success, BOOL hasData);

@interface BRHRemoteDriver : NSObject

@property (nonatomic, assign) double serverWhen;
@property (nonatomic, assign) double deviceOffset;

- (id)initWithURL:(NSURL*)url deviceToken:(NSString*)deviceToken;
- (void)postRegistration;
- (void)deleteRegistration;

- (void)fetchMessage:(NSInteger)msgId withCompletionHandler:(BRHRemoteDriverFetchCompletionBlock)completionHandler;

- (void)updateWithCompletionHandler:(BRHRemoteDriverFetchCompletionBlock)completionHandler;

- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end
