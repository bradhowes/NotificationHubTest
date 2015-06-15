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

@property (strong, nonatomic) NSMutableArray *plots;

- (void)updateTitle;
- (void)makeGraph;
- (void)makePlots;
- (CPTPlotRange *)findMinMaxInRange:(CPTPlotRange *)range;
- (void)updateBounds:(NSUInteger )pointsAdded;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
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
        [self makeGraph];
        [self makePlots];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHRunDataNewDataNotification object:nil];
    }
    
    [_plots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BRHLatencyByTimeGraphPlot *plot = obj;
        plot.runData = runData;
    }];
    
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

    // self.backgroundColor = [UIColor blackColor];
}

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
    float w = self.hostedGraph.frame.size.width;
    return floor(w / (kPlotSymbolSize * 1.5));
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

    NSTimeInterval minLatency = 0;
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

    if (xMin == 0.0) {
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:CPTDecimalFromDouble(xMax - xMin + emitInterval)];
        
    }
    else if (pointsAdded && xMax - plotSpace.xRange.endDouble < pointsAdded * emitInterval) {
        CPTPlotRange *oldRange = plotSpace.xRange;
        CPTPlotRange *newRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(xMin) length:CPTDecimalFromDouble(xMax - xMin + emitInterval)];
        [CPTAnimation animate:plotSpace property:@"xRange" fromPlotRange:oldRange toPlotRange:newRange duration:CPTFloat(0.25)];
    }

    CPTPlotRange *yRange = [self findMinMaxInRange:plotSpace.xRange];
    if (! yRange) {
        yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(1.0)];
    }

    plotSpace.globalYRange = yRange;
    plotSpace.yRange = yRange;

    CPTXYAxisSet *axisSet = self.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;

    x.visibleAxisRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromDouble(xMax)];
    x.visibleRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromDouble(xMax)];

    y.visibleAxisRange = yRange;
    y.visibleRange = yRange;
    x.gridLinesRange = yRange;

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

- (void)plotSpace:(CPTPlotSpace *)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateX) {
        
        // Clear any annotation that is no longer visible
        //
        CPTPlotRange *xRange = ((CPTXYPlotSpace *)space).xRange;
        CPTPlotRange *yRange = [self findMinMaxInRange:xRange];
        if (yRange) {
            CPTXYPlotSpace *plotSpace = self.plotSpace;
            plotSpace.globalYRange = yRange;
            plotSpace.yRange = yRange;

            CPTXYAxisSet *axisSet = self.axisSet;
            CPTXYAxis *x = axisSet.xAxis;
            CPTXYAxis *y = axisSet.yAxis;
            y.visibleAxisRange = yRange;
            y.visibleRange = yRange;
            x.gridLinesRange = yRange;
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
