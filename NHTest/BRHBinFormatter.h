//
//  BRHBinFormatter.h
//  NotificationHubTest
//
//  Created by Brad Howes on 1/7/14.
//  Copyright (c) 2014 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHBinFormatter : NSNumberFormatter
@property (assign, nonatomic) NSInteger maxBins;

+ (BRHBinFormatter*)binFormatterWithMaxBins:(NSInteger)maxBins;
- (id)initWithMaxBins:(NSInteger)maxBins;

@end

