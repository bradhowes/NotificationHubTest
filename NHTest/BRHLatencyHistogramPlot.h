// BRHCountBars.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@class BRHRunData;

/*!
 A Core Plot bar chart with vertical bars that represents the contents of a histogram of arrival latencies with 1-second bins.
 */
@interface BRHLatencyHistogramPlot : CPTGraphHostingView

/*!
 * @brief Create the plot.
 *
 * @param driver the experiment driver that contains the data to plot
 */
- (void)useDataSource:(BRHRunData *)runData;

/*!
 * @brief Generate the plot as a PDF image
 *
 * @param pdfContext the PDF context to render in
 */
- (void)renderPDF:(CGContextRef)pdfContext;

- (void)redraw;

@end
