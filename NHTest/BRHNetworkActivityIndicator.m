// BRHNetworkActivityIndicator.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHNetworkActivityIndicator.h"

@implementation BRHNetworkActivityIndicator

- (instancetype)init
{
    if (self = [super init]) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    }
    return self;
}

- (void)dealloc
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
