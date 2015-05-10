//
//  BRHBackgroundManager.h
//  NHTest
//
//  Created by Brad Howes on 2/11/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHBackgroundManager : NSObject

@property(nonatomic, readonly) BOOL isRunning;

-(void)startTask;
-(void)endTask;
-(BOOL)isInBackground;

@end
