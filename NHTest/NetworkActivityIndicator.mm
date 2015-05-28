//
//  NetworkActivityIndicator.mm
//  Datac
//
//  Created by Brad Howes on 6/7/11.
//  Copyright 2011 Brad Howes. All rights reserved.
//

#import "NetworkActivityIndicator.h"


@implementation NetworkActivityIndicator

- (id)init
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
