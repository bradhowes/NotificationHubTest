//
//  BRHOutstandingNotification.h
//  NHTest
//
//  Created by Brad Howes on 5/10/15.
//  Copyright (c) 2015 Brad Howes. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRHOutstandingNotification : NSObject

@property (nonatomic, strong) NSDate *when;
@property (nonatomic, strong) NSDate *expiration;
@property (nonatomic, strong) NSNumber *identifier;

@end
