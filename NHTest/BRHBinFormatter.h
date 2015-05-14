//
//  BRHBinFormatter.h
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHBinFormatter : NSNumberFormatter

+ (BRHBinFormatter*)binFormatterWithMaxBins:(NSUInteger)maxBins;
- (id)initWithMaxBins:(NSUInteger)maxBins;

@end

