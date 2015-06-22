// BRHLatencyPlot.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimeGraph.h"
#import "BRHLatencyByTimeGraphLatencyPlot.h"
#import "BRHLatencyByTimeGraphAveragePlot.h"
#import "BRHLatencyByTimeGraphMedianPlot.h"
#import "BRHLatencyByTimeGraphMissingPlot.h"
#import "BRHLatencySample.h"
#import "BRHLogger.h"
#import "BRHRunData.h"
#import "BRHTimeFormatter.h"
#import "BRHUserSettings.h"

static double const kPlotSymbolSize = 8.0;

@interface BRHLatencyByTimeGraph () <CPTPlotSpaceDelegate, CPTLegendDelegate>

/*!
 @brief Container of plots that make up the graph.
 */
@property (strong, nonatomic) NSMutableArray *plots;

/*!
 @brief True when the user is zooming due to vertical dragging.
 */
@property (assign, nonatomic) BOOL zooming;

/*!
 @brief The original Y range before zooming began.
 */
@property (strong, nonatomic) CPTPlotRange *unzooomedYRange;

/*!
 @brief The starting position of the drag event.
 */
@property (assign, nonatomic) CGPoint dragStart;

/*!
 @brief The starting position in Y of the drag in plot space coordinates.
 */
@property (assign, nonatomic) double startY;

/*!
 @brief Update the title of the plot using the settings in the BRHRunData instance.
 */
- (void)updateTitle;

/*!
 @brief Create the graph container that holds the plots
 */
- (void)makeGraph;

/*!
 @brief Create the plots for the graph.
 */
- (void)makePlots;

/*!
 @brief Obtain the min and max Y values for the given X range.
 
 @param range the X range to query

 @return new CPTPlotRange representing the min/max values
 */
- (CPTPlotRange *)findMinMaxInRange:(CPTPlotRange *)range;

/*!
 @brief Update the X and Y ranges to reflect new data.
 
 Scrolls the X view to reveal new data if the current view is showing the end of the existing data.
 
 @param pointsAdded number of new points added
 */
- (void)updateBounds:(NSUInteger )pointsAdded;

/*!
 @brief Handler for 2-tap gesture.
 
 Show or hide the legend.
 
 @param recognizer the UITapGestureRecognizer that invoked the handler
 */
- (void)handleTap:(UITapGestureRecognizer *)recognizer;

/*!
 @brief Notification handler when new data appears in the BRHRunData.
 
 Update the plots so that they know about the new data. The notification parameter contains a description of the new 
 data added to BRHRunData.
 
 *
 
 @param notification the description of the notification.
 */
- (void)update:(NSNotification *)notification;
@end

@implementation BRHLatencyByTimeGraph

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRunData:(BRHRunData *)runData
{
    _runData = runData;
    if (! self.hostedGraph) {
        _plots = [NSMutableArray arrayWithCapacity:4];
        _zooming = NO;
        _unzooomedYRange = nil;
        [self makeGraph];
        [self makePlots];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHRunDataNewDataNotification object:nil];
    }
    
    [_plots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BRHLatencyByTimeGraphPlot *plot = obj;
        plot.runData = runData;
    }];
    
    CPTPlotRange * xMinMax = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(1E99)];
    CPTPlotRange * yMinMax = [self findMinMaxInRange:xMinMax];
    self.plotSpace.globalYRange = yMinMax;
    self.axisSet.yAxis.visibleAxisRange = yMinMax;
    self.axisSet.yAxis.visibleRange = yMinMax;
    self.axisSet.xAxis.gridLinesRange = yMinMax;
    
    [self updateBounds:0];
    [self updateTitle];
}

- (void)makePlots
{
    // Create the plots then add them to our graph
    //
    [_plots addObject:[[BRHLatencyByTimeGraphAveragePlot alloc] initFor:self]];
    [_plots addObject:[[BRHLatencyByTimeGraphMedianPlot alloc] initFor:self]];
    [_plots addObject:[[BRHLatencyByTimeGraphMissingPlot alloc] initFor:self]];
    [_plots addObject:[[BRHLatencyByTimeGraphLatencyPlot alloc] initFor:self]];
    for (BRHLatencyByTimeGraphPlot *plot in _plots) {
        [self.hostedGraph addPlot:plot.plot];
    }

    // Now we can add our legend
    //
    CPTLegend *legend = [CPTLegend legendWithGraph:self.hostedGraph];
    self.hostedGraph.legend = legend;
    self.hostedGraph.legendAnchor = CPTRectAnchorTop;
    self.hostedGraph.legendDisplacement = CGPointMake(0.0, -5.0);

    legend.hidden = YES;
    legend.fill = [CPTFill fillWithColor:[[CPTColor darkGrayColor] colorWithAlphaComponent:0.5]];

    CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor colorWithGenericGray:0.75];
    textStyle.fontSize = 11.0f;
    legend.textStyle = textStyle;

    CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 0.75;
    lineStyle.lineColor = [CPTColor colorWithGenericGray:0.45];

    legend.borderLineStyle = lineStyle;
    legend.cornerRadius = 5.0;
    legend.swatchSize = CGSizeMake(25.0, 25.0);
    legend.numberOfRows = 1;
    legend.delegate = self;

    // Create a 2-tap gesture recognizer to show/hide the legend
    //
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    
    recognizer.numberOfTouchesRequired = 1;
    recognizer.numberOfTapsRequired = 2;
    
    [self addGestureRecognizer:recognizer];
}

- (CPTXYGraph *)graph
{
    return (CPTXYGraph *)self.hostedGraph;
}

- (CPTXYPlotSpace *)plotSpace
{
    return (CPTXYPlotSpace *) self.graph.defaultPlotSpace;
}

- (CPTXYAxisSet *)axisSet
{
    return (CPTXYAxisSet *)self.graph.axisSet;
}

- (NSTimeInterval)xValueFor:(BRHLatencySample *)sample
{
    return [sample.emissionTime timeIntervalSinceDate:_runData.startTime];
}

- (void)updateTitle
{
    CPTXYAxisSet *axisSet = self.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.title = [NSString stringWithFormat:@"%@ - %lds Intervals", self.runData.name, (long)self.runData.emitInterval.integerValue];
}

- (void)makeGraph
{
    CPTXYGraph *graph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
    self.hostedGraph = graph;
    // [graph applyTheme:[CPTTheme themeNamed:kCPTDarkGradientTheme]];

    graph.paddingLeft = 0.0f;
    graph.paddingRight = 0.0f;
    graph.paddingTop = 0.0f;
    graph.paddingBottom = 0.0f;
    
    graph.plotAreaFrame.borderLineStyle = nil;
    graph.plotAreaFrame.cornerRadius = 0.0f;

    graph.plotAreaFrame.paddingTop = 10.0;
    graph.plotAreaFrame.paddingLeft = 35.0;
    graph.plotAreaFrame.paddingBottom = 35.0;
    graph.plotAreaFrame.paddingRight = 10.0;

    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    axisLineStyle.lineWidth = 0.75;
    axisLineStyle.lineColor = [CPTColor colorWithGenericGray:0.45];
    
    CPTMutableLineStyle *gridLineStyle = [CPTMutableLineStyle lineStyle];
    gridLineStyle.lineWidth = 0.75;
    gridLineStyle.lineColor = [CPTColor colorWithGenericGray:0.25];
    
    CPTMutableLineStyle *tickLineStyle = [CPTMutableLineStyle lineStyle];
    tickLineStyle.lineWidth = 0.75;
    tickLineStyle.lineColor = [CPTColor colorWithGenericGray:0.45];
    
    CPTMutableTextStyle *labelTextStyle = [CPTMutableTextStyle textStyle];
    labelTextStyle.color = [CPTColor colorWithGenericGray:0.75];
    labelTextStyle.fontSize = 12.0f;
    
    CPTMutableTextStyle *titleTextStyle = [CPTMutableTextStyle textStyle];
    titleTextStyle.color = [CPTColor colorWithGenericGray:0.75];
    titleTextStyle.fontSize = 11.0f;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.identifier = BRHLatencySampleLatencyKey;
    plotSpace.allowsUserInteraction = YES;

    plotSpace.allowsMomentumX = YES;
    plotSpace.allowsMomentumY = NO;
    plotSpace.delegate = self;
    
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;

    // X axis
    //
    x.titleTextStyle = titleTextStyle;
    x.titleOffset = 18.0;

    x.axisLineStyle = nil;
    x.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];     // Keep the X axis from moving up/down when scrolling

    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    x.labelTextStyle = labelTextStyle;
    x.labelOffset = -4.0;

    BRHTimeFormatter *formatter = [BRHTimeFormatter sharedTimeFormatter];
    x.labelFormatter = formatter;
    
    x.tickDirection = CPTSignNegative;
    x.majorTickLineStyle = tickLineStyle;
    x.majorTickLength = 5.0;
    x.majorIntervalLength = CPTDecimalFromInt(10);

    x.minorTickLineStyle = nil;
    x.minorTicksPerInterval = 0;
    
    x.majorGridLineStyle = gridLineStyle;
    x.minorGridLineStyle = nil;

    // Y axis
    //
    y.titleTextStyle = nil;
    y.title = nil;
    y.preferredNumberOfMajorTicks = 5;

    y.axisLineStyle = nil;
    y.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];

    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.labelingPolicy = CPTAxisLabelingPolicyEqualDivisions;
    y.majorGridLineStyle = gridLineStyle;
    y.minorGridLineStyle = nil;

    y.labelTextStyle = labelTextStyle;
    y.labelOffset = 0.0;
    y.majorTickLineStyle = nil;
    y.minorTickLineStyle = nil;
    y.tickDirection = CPTSignNone;
}

/*!
 @brief Overide of UIView method so that we can update min/max bounds when the graph size changes.
 */
- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateBounds:0];
}

- (void)redraw
{
    [self.hostedGraph.allPlots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL* stop) {
        [obj setDataNeedsReloading];
    }];
    [self updateBounds:0];
}

- (NSUInteger)calculatePlotWidth
{
    double w = self.hostedGraph.frame.size.width;
    return (NSUInteger)floor(w / (kPlotSymbolSize * 1.5));
}

- (void)renderPDF:(CGContextRef)pdfContext
{
    CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;

    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    CPTPlotRange *savedXRange = plotSpace.xRange;
    plotSpace.xRange = plotSpace.globalXRange;
    CPTPlotRange *savedYRange = plotSpace.yRange;
    plotSpace.yRange = plotSpace.globalYRange;

    CGRect mediaBox = CPTRectMake(0, 0, graph.bounds.size.width, graph.bounds.size.height);
    CGContextBeginPage(pdfContext, &mediaBox);

    [graph layoutAndRenderInContext:pdfContext];
    CGContextEndPage(pdfContext);

    plotSpace.xRange = savedXRange;
    plotSpace.yRange = savedYRange;
}

- (NSUInteger)findFirstPointAtOrAfter:(NSTimeInterval )when inArray:(NSArray *)array
{
    BRHLatencySample *tmp = [BRHLatencySample new];
    tmp.emissionTime = [_runData.startTime dateByAddingTimeInterval:when];
    NSRange range = NSMakeRange(0, array.count);
    NSUInteger index = [array indexOfObject:tmp inSortedRange:range options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual usingComparator:^NSComparisonResult(id obj1, id obj2) {
        BRHLatencySample *sample1 = obj1;
        BRHLatencySample *sample2 = obj2;
        return [sample1.emissionTime compare:sample2.emissionTime];
    }];
    
    return index;
}

- (NSUInteger)findLastPointAtOrBefore:(NSTimeInterval )when inArray:(NSArray *)array
{
    BRHLatencySample *tmp = [BRHLatencySample new];
    tmp.emissionTime = [_runData.startTime dateByAddingTimeInterval:when];
    NSRange range = NSMakeRange(0, array.count);
    NSUInteger index = [array indexOfObject:tmp inSortedRange:range options:NSBinarySearchingInsertionIndex | NSBinarySearchingLastEqual usingComparator:^NSComparisonResult(id obj1, id obj2) {
        BRHLatencySample *sample1 = obj1;
        BRHLatencySample *sample2 = obj2;
        return [sample1.emissionTime compare:sample2.emissionTime];
    }];
    
    return index;
}

- (CPTPlotRange *)findMinMaxInRange:(CPTPlotRange *)range
{
    if (_runData.samples.count == 0) {
        return nil;
    }

    NSTimeInterval minLatency = 0.0;
    NSTimeInterval maxLatency = 0.0;

    NSUInteger x0 = [self findFirstPointAtOrAfter:range.locationDouble inArray:_runData.samples];
    NSUInteger x1 = [self findLastPointAtOrBefore:range.endDouble inArray:_runData.samples];

    while (x0 < x1) {
        NSTimeInterval latency = ((BRHLatencySample *)_runData.samples[x0++]).latency.doubleValue;
        if (latency > maxLatency) maxLatency = latency;
    }
    
    maxLatency = floor(10.0 * (maxLatency + 0.5)) / 10.0;

    return [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minLatency) length:CPTDecimalFromDouble(maxLatency - minLatency)];
}

- (void)updateBounds:(NSUInteger )pointsAdded
{
    NSUInteger visiblePoints = [self calculatePlotWidth];
    NSTimeInterval emitInterval = _runData.emitInterval.integerValue;

    NSArray *plotData = _runData.samples;
    NSTimeInterval xMin = 0.0;
    NSTimeInterval xMax = (visiblePoints - 1) * emitInterval;

    if (plotData.count) {
        BRHLatencySample *tmp = [plotData lastObject];
        NSTimeInterval xPos = [self xValueFor:tmp];
        if (xPos > xMax) {
            xMin = xPos - xMax;
            xMax = xPos;
        }
    }

    NSDecimal xMin1 = CPTDecimalFromDouble(0.0 - emitInterval / 2.0 );
    NSDecimal xMax1 = CPTDecimalFromDouble(xMax + emitInterval);

    CPTXYPlotSpace *plotSpace = self.plotSpace;
    plotSpace.globalXRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:xMax1];

    BOOL fitY = pointsAdded == 0;
    if (xMin == 0.0) {
        
        // Nothing going on here -- just show a default range of X
        //
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:CPTDecimalFromDouble(xMax - xMin + emitInterval)];
        fitY = YES;
        
    }
    else if (pointsAdded && xMax - plotSpace.xRange.endDouble < pointsAdded * emitInterval) {
        
        // Scroll the view to show the new points
        //
        CPTPlotRange *oldRange = plotSpace.xRange;
        CPTPlotRange *newRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(xMin) length:CPTDecimalFromDouble(xMax - xMin + emitInterval)];
        [CPTAnimation animate:plotSpace property:@"xRange" fromPlotRange:oldRange toPlotRange:newRange duration:CPTFloat(0.25)];
        fitY = YES;
    }

    CPTPlotRange *yRange = [self findMinMaxInRange:plotSpace.xRange];
    if (! yRange) {
        yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(1.0)];
    }

    if (fitY) {
        plotSpace.yRange = yRange;
    }

    CPTXYAxisSet *axisSet = self.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;

    x.visibleAxisRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromDouble(xMax)];
    x.visibleRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromDouble(xMax)];

    y.gridLinesRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:xMax1];
}

- (void)update:(NSNotification *)notification;
{
    BRHRunDataNotificationInfo *info = notification.userInfo[@"info"];
    for (BRHLatencyByTimeGraphPlot *plot in _plots) {
        [plot update:info];
    }

    [self updateBounds:info.missingCount + info.sampleCount];
}

#pragma mark -
#pragma mark Plot Space Delegate Methods

- (BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceDownEvent:(id)event atPoint:(CGPoint)point
{
    // Start with the assumption that we will be zooming. We don't know until we have a second point to compare to see
    // if the dragging is in the X or Y direction.
    //
    _zooming = YES;
    _dragStart = point;
    _unzooomedYRange = [CPTPlotRange plotRangeWithLocation:self.plotSpace.yRange.location
                                                    length:self.plotSpace.yRange.length];
    //    NSLog(@"event point: %f", point.y);

    CPTPlotArea *plotArea = self.hostedGraph.plotAreaFrame.plotArea;
    CGPoint dragStartInPlotArea = [self.hostedGraph convertPoint:point toLayer:plotArea];
    NSLog(@"dragStartInPlotArea: %f", dragStartInPlotArea.y);
    if (dragStartInPlotArea.y < 5) {
        _zooming = NO;
        return YES;
    }

    CPTXYPlotSpace *plotSpace = self.plotSpace;
    double start[2];
    [plotSpace doublePrecisionPlotPoint:start numberOfCoordinates:2 forPlotAreaViewPoint:dragStartInPlotArea];
    NSLog(@"plotSpace: %f", start[1]);
    _startY = log(MAX(start[1], DBL_EPSILON));

    return YES;
}

- (BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceDraggedEvent:(UIEvent *)event atPoint:(CGPoint)point
{
    if (! _zooming) return YES;

    // Stop zooming if the user is really dragging horizontally
    //
    if (ABS(point.x - _dragStart.x) > ABS(point.y - _dragStart.y)) {
        _zooming = NO;
        self.plotSpace.yRange = _unzooomedYRange;
        return YES;
    }

    CPTXYPlotSpace *plotSpace = self.plotSpace;
    CPTPlotRange *lastRange = plotSpace.yRange;
    plotSpace.yRange = _unzooomedYRange;

    CPTPlotArea *plotArea = self.hostedGraph.plotAreaFrame.plotArea;
    CGPoint dragEndInPlotArea = [self.hostedGraph convertPoint:point toLayer:plotArea];

    double end[2];
    [plotSpace doublePrecisionPlotPoint:end numberOfCoordinates:2 forPlotAreaViewPoint:dragEndInPlotArea];
    double scale = exp(log(end[1]) - _startY);
    NSLog(@"scale %f", scale);

    if (isnan(scale)) {
        plotSpace.yRange = lastRange;
        return NO;
    }

    double yRangeMax = MAX(_unzooomedYRange.lengthDouble / scale, 0.001);
    CPTPlotRange *yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(yRangeMax)];
    plotSpace.yRange = yRange;

    CPTXYAxisSet *axisSet = self.axisSet;
    axisSet.xAxis.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    axisSet.yAxis.labelingPolicy = CPTAxisLabelingPolicyAutomatic;

    return NO;
}

- (BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceUpEvent:(id)event atPoint:(CGPoint)point
{
    _zooming = NO;
    return YES;
}

- (BOOL)plotSpace:(CPTPlotSpace *)space shouldHandlePointingDeviceCancelledEvent:(id)event atPoint:(CGPoint)point
{
    _zooming = NO;
    return YES;
}

- (void)plotSpace:(CPTPlotSpace *)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateY) {
        CPTXYPlotSpace *plotSpace = self.plotSpace;
        CPTPlotRange *yRange = plotSpace.yRange;
        if (yRange.locationDouble != 0.0) {
            yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:yRange.length];
            plotSpace.yRange = yRange;
        }
    }
}

#pragma mark - Tab Gesture Methods

- (void)handleTap:(UITapGestureRecognizer *)sender
{
    self.hostedGraph.legend.hidden = ! self.hostedGraph.legend.hidden;
}

#pragma mark - Legend Delegate Methods

- (void)legend:(CPTLegend *)legend legendEntryForPlot:(CPTPlot *)plot wasSelectedAtIndex:(NSUInteger)idx
{
    plot.hidden = ! plot.hidden;
}

@end
