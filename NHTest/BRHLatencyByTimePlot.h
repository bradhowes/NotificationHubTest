// BRHLatencyPlot.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@class BRHRunData;

@interface BRHLatencyByTimePlot : CPTGraphHostingView

- (void)useDataSource:(BRHRunData *)dataSource;

- (void)renderPDF:(CGContextRef)pdfContext;

- (void)redraw;

@end
