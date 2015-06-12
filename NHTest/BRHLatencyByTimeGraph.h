// BRHLatencyPlot.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <UIKit/UIKit.h>

#import "CorePlot-CocoaTouch.h"

@class BRHLatencySample;
@class BRHRunData;

/*!
 @brief Graph of the notificaton latencies.
 
 The graph contains four plots: measured latencies, average latency, median latency, and missing notifications. Each
 plot is derived from BRHLatencyByTimeGraphPlot.
 */
@interface BRHLatencyByTimeGraph : CPTGraphHostingView

/*!
 @brief The data being used for the plots
 */
@property(strong, nonatomic) BRHRunData *runData;

/*!
 @brief Render the graph as a PDF
 
 @param pdfContext the PDF context to draw in
 */
- (void)renderPDF:(CGContextRef)pdfContext;

/*!
 @brief Redraw the graph.
 */
- (void)redraw;

/*!
 @brief Sugar to obtain the graph as a CPTXYGraph object
 
 @return CPTXYGraph object
 */
- (CPTXYGraph *)graph;

/*!
 @brief Sugar to obtain the axis set as a CPTXYAxisSet object
 
 @return CPTXYAxisSet object
 */
- (CPTXYAxisSet *)axisSet;

/*!
 @brief Sugar to obtain the plot space as a CPTXYPlotSpace object
 
 @return CPTXYPlotSpace object
 */
- (CPTXYPlotSpace *)plotSpace;

/*!
 @brief Obtain the time offset for a BRHLatencySample.
 
 The time offset is used for locating the sample on the X axis. The offset
 is calculated between the start of the run and the emissionTime attribute.
 
 @param sample <#sample description#>
 
 @return <#return value description#>
 */
- (NSTimeInterval)xValueFor:(BRHLatencySample *)sample;

/*!
 @brief Obtain an estimate of the number of samples that will display on the X axis of the latency graph.
 
 @return count of BRHLatencySample values to show
 */
- (NSUInteger)calculatePlotWidth;

/*!
 @brief Locate the first BRHLatencySample instance whose emissionTime is >= the given time.
 
 @param when the timestamp to look for
 @param array the container to search

 @return the index of the value that was found
 */
- (NSUInteger)findFirstPointAtOrAfter:(NSTimeInterval)when
                              inArray:(NSArray *)array;
/*!
 @brief Locate the last BRHLatencySample instance whose emission time is <= the given time

 @param when the timestamp to look for
 @param array the container to search
 
 @return the index of the value that was found
 */
- (NSUInteger)findLastPointAtOrBefore:(NSTimeInterval)when
                              inArray:(NSArray *)array;

@end
