//
//  BRHLatencyPlot.h
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@class BRHNotificationDriver;

@interface BRHLatencyPlot : CPTGraphHostingView

- (void)initialize:(BRHNotificationDriver *)driver;

- (void)renderPDF:(CGContextRef)pdfContext;

@end
