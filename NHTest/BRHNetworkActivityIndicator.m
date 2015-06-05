// BRHNetworkActivityIndicator.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHNetworkActivityIndicator.h"

static int counter = 0;

@implementation BRHNetworkActivityIndicator

- (instancetype)init
{
    if (self = [super init]) {
        counter += 1;
        if (counter == 1) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
    }
    return self;
}

- (void)dealloc
{
    if (counter > 0) counter -= 1;
    if (counter == 0) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }
}

@end
