// BRHLatencyPlot.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@class BRHNotificationDriver;

@interface BRHLatencyByTimePlot : CPTGraphHostingView

- (void)useDataSource:(NSArray *)dataSource title:(NSString *)title emitInterval:(NSNumber *)emitInterval;

- (void)renderPDF:(CGContextRef)pdfContext;

- (void)redraw;

@end
