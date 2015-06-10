// BRHLatencyPlot.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimePlot.h"
#import "BRHLatencySample.h"
#import "BRHLogger.h"
#import "BRHRunData.h"
#import "BRHTimeFormatter.h"
#import "BRHUserSettings.h"

static double const kPlotSymbolSize = 8.0;

@interface BRHLatencyByTimePlot () <CPTPlotDataSource, CPTPlotSpaceDelegate>

@property (strong, nonatomic) BRHRunData *dataSource;
@property (strong, nonatomic) CPTPlotSpaceAnnotation *annotation;
@property (assign, nonatomic) NSUInteger annotationIndex;

- (void)updateTitle;
- (void)makePlot;
- (NSUInteger)calculatePlotWidth;
- (NSTimeInterval)xValueFor:(BRHLatencySample *)sample;
- (NSUInteger)findPointFor:(NSTimeInterval )when;
- (CPTPlotRange *)findMinMaxInRange:(CPTPlotRange *)range;
- (void)updateBounds;
- (void)update:(NSNotification *)notification;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;

@end

@implementation BRHLatencyByTimePlot

- (void)useDataSource:(BRHRunData *)dataSource
{
    if (self.annotation != nil) {
        [self.hostedGraph.plotAreaFrame.plotArea removeAnnotation:self.annotation];
        self.annotation = nil;
    }

    self.dataSource = dataSource;

    if (! self.hostedGraph) {
        [self makePlot];
    }
    else {
        [self redraw];
    }

    [self updateTitle];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHRunDataNewDataNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateTitle
{
    CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.title = [NSString stringWithFormat:@"%@ - %lds Intervals", self.dataSource.name, (long)self.dataSource.emitInterval.integerValue];
}

- (void)makePlot
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
    x.preferredNumberOfMajorTicks = 10;

    x.axisLineStyle = nil;
    x.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];     // Keep the X axis from moving up/down when scrolling

    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    x.labelTextStyle = labelTextStyle;
    x.labelOffset = -4.0;

    BRHTimeFormatter *formatter = [BRHTimeFormatter new];
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


    CPTScatterPlot *plot;

    // Average plot
    //
    plot = [[CPTScatterPlot alloc] init];
    plot.identifier = BRHLatencySampleAverageKey;
    plot.cachePrecision = CPTPlotCachePrecisionDouble;
    
    CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineJoin = kCGLineJoinRound;
    lineStyle.lineCap = kCGLineCapRound;
    lineStyle.lineWidth = 3.0f;
    lineStyle.lineColor = [[CPTColor yellowColor] colorWithAlphaComponent:1.0];
    plot.dataLineStyle = lineStyle;
    
    plot.dataSource = self;
    [graph addPlot:plot];
    
    // Median plot
    //
    plot = [[CPTScatterPlot alloc] init];
    plot.identifier = BRHLatencySampleMedianKey;
    plot.cachePrecision = CPTPlotCachePrecisionDouble;
    
    lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineJoin = kCGLineJoinRound;
    lineStyle.lineCap = kCGLineCapRound;
    lineStyle.lineWidth = 3.0f;
    lineStyle.lineColor = [[CPTColor magentaColor] colorWithAlphaComponent:1.0];

    plot.dataLineStyle = lineStyle;
    
    plot.dataSource = self;
    [graph addPlot:plot];
    
    // Latency plot
    //
    plot = [[CPTScatterPlot alloc] init];
    plot.identifier = BRHLatencySampleLatencyKey;
    plot.cachePrecision = CPTPlotCachePrecisionDouble;
    
    lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 1.0f;
    lineStyle.lineColor = [CPTColor grayColor];
    plot.dataLineStyle = lineStyle;

    // Add plot symbols
    CPTGradient *symbolGradient = [CPTGradient gradientWithBeginningColor:[CPTColor colorWithComponentRed:0.75 green:0.75 blue:1.0 alpha:1.0]
                                                              endingColor:[CPTColor cyanColor]];
    symbolGradient.gradientType = CPTGradientTypeRadial;
    symbolGradient.startAnchor  = CPTPointMake(0.25, 0.75);
    
    CPTPlotSymbol *plotSymbol = [CPTPlotSymbol ellipsePlotSymbol];
    plotSymbol.fill = [CPTFill fillWithGradient:symbolGradient];
    plotSymbol.lineStyle = nil;
    plotSymbol.size = CGSizeMake(kPlotSymbolSize, kPlotSymbolSize);
    plot.plotSymbol = plotSymbol;

    plot.dataSource = self;
    plot.delegate = self;
    plot.plotSymbolMarginForHitDetection = kPlotSymbolSize * 1.5;
    
    [graph addPlot:plot];
    
    // Legend
    //
    CPTLegend *legend = [CPTLegend legendWithGraph:graph];
    graph.legend = legend;
    legend.hidden = YES;
    legend.fill = [CPTFill fillWithColor:[[CPTColor darkGrayColor] colorWithAlphaComponent:0.5]];
    legend.textStyle = titleTextStyle;
    legend.borderLineStyle = x.axisLineStyle;
    legend.cornerRadius = 5.0;
    legend.swatchSize = CGSizeMake(25.0, 25.0);
    legend.numberOfRows = 1;
    legend.delegate = self;
    graph.legendAnchor = CPTRectAnchorTop;
    graph.legendDisplacement = CGPointMake(0.0, 0.0);
    
    // self.backgroundColor = [UIColor blackColor];

    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];

    recognizer.numberOfTouchesRequired = 1;
    recognizer.numberOfTapsRequired = 2;

    [self addGestureRecognizer:recognizer];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateBounds];
}

- (void)redraw
{
    [self.hostedGraph.allPlots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL* stop) {
        [obj setDataNeedsReloading];
    }];
    [self updateBounds];
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

- (NSTimeInterval)xValueFor:(BRHLatencySample *)sample
{
    return [sample.emissionTime timeIntervalSinceDate:_dataSource.startTime];
}

- (NSUInteger)findPointFor:(NSTimeInterval )when
{
    BRHLatencySample *tmp = [BRHLatencySample new];
    tmp.emissionTime = [_dataSource.startTime dateByAddingTimeInterval:when];
    NSRange range = NSMakeRange(0, _dataSource.samples.count);
    NSUInteger index = [_dataSource.samples indexOfObject:tmp inSortedRange:range options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(id obj1, id obj2) {
        BRHLatencySample *sample1 = obj1;
        BRHLatencySample *sample2 = obj2;
        return [sample1.emissionTime compare:sample2.emissionTime];
    }];
    
    return index;
}

- (CPTPlotRange *)findMinMaxInRange:(CPTPlotRange *)range
{
    if (_dataSource.samples.count == 0) {
        return nil;
    }

    NSTimeInterval minLatency = 1e9;
    NSTimeInterval maxLatency = 0.0;

    NSUInteger x0 = [self findPointFor:range.locationDouble];
    NSUInteger x1 = [self findPointFor:range.endDouble];

    if (x1 - x0 < 2) {
        return nil;
    }

    while (x0 < x1) {
        NSTimeInterval latency = ((BRHLatencySample *)_dataSource.samples[x0++]).latency.doubleValue;
        if (latency < minLatency) minLatency = latency;
        if (latency > maxLatency) maxLatency = latency;
    }
    
    minLatency = ceil(10.0 * (minLatency - 0.5)) / 10.0;
    maxLatency = floor(10.0 * (maxLatency + 0.5)) / 10.0;

    return [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(minLatency) length:CPTDecimalFromDouble(maxLatency - minLatency)];
}

- (void)updateBounds
{
    NSUInteger visiblePoints = [self calculatePlotWidth];
    NSTimeInterval emitInterval = _dataSource.emitInterval.integerValue;

    NSArray *plotData = _dataSource.samples;
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

    CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;

    plotSpace.globalXRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:xMax1];

    if (xMin == 0.0) {
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:xMin1
                                                        length:CPTDecimalFromDouble(xMax - xMin + emitInterval)];
        
    }
    else if (xMax - plotSpace.xRange.endDouble < 2 * emitInterval) {
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(xMin)
                                                        length:CPTDecimalFromDouble(xMax - xMin + emitInterval)];
    }

    CPTPlotRange *yRange = [self findMinMaxInRange:plotSpace.xRange];
    if (! yRange) {
        yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(1.0)];
    }
    plotSpace.globalYRange = yRange;
    plotSpace.yRange = yRange;

    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;

    x.visibleAxisRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromDouble(xMax)];
    x.visibleRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0) length:CPTDecimalFromDouble(xMax)];

    y.visibleAxisRange = yRange;
    y.visibleRange = yRange;
    x.gridLinesRange = yRange;

    y.gridLinesRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:xMax1];
}

- (void)update:(NSNotification *)notification
{
    CPTXYGraph *theGraph = (CPTXYGraph *)self.hostedGraph;
    if (theGraph == nil) return;

    // Add a new value to the plots, causing them to fetch a new value from the data source
    //
    NSNumber *newSampleIndex = notification.userInfo[@"newSampleIndex"];
    NSNumber *newSampleCount = notification.userInfo[@"newSampleCount"];
    for (CPTPlot* plot in [theGraph allPlots]) {
        [plot insertDataAtIndex:newSampleIndex.integerValue numberOfRecords:newSampleCount.integerValue];
    }

    [self updateBounds];
}

#pragma mark Data Source Methods

- (NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return self.dataSource.samples.count;
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = [NSDecimalNumber zero];
    NSString *key = nil;
    BRHLatencySample *sample;
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            sample = _dataSource.samples[index];
            num = [NSNumber numberWithDouble:[self xValueFor:sample]];
            break;

        case CPTScatterPlotFieldY:
            sample = _dataSource.samples[index];
            key = (NSString *)plot.identifier;
            num = [sample valueForKey:key];
            break;
            
        default:
            break;
    }

    return num;
}

#pragma mark -
#pragma mark Plot Space Delegate Methods


- (void)plotSpace:(CPTPlotSpace *)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateX) {
        
        // Clear any annotation that is no longer visible
        //
        CPTPlotRange *xRange = ((CPTXYPlotSpace *)space).xRange;
        if (self.annotation != nil) {
            BRHLatencySample *sample = _dataSource.samples[self.annotationIndex];
            if (! [xRange containsNumber:sample.identifier]) {
                CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;
                [graph.plotAreaFrame.plotArea removeAnnotation:self.annotation];
                self.annotation = nil;
            }
        }

        CPTPlotRange *yRange = [self findMinMaxInRange:xRange];
        if (yRange) {
            CPTXYGraph *theGraph = (CPTXYGraph *)self.hostedGraph;
            CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
            CPTXYAxisSet *axisSet = (CPTXYAxisSet *)theGraph.axisSet;
            CPTXYAxis *x = axisSet.xAxis;
            CPTXYAxis *y = axisSet.yAxis;

            plotSpace.globalYRange = yRange;
            plotSpace.yRange = yRange;
            y.visibleAxisRange = yRange;
            y.visibleRange = yRange;
            x.gridLinesRange = yRange;
        }
    }
}

#pragma mark - Plot Delegate Methods

-(void)scatterPlot:(CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)index
{
    BRHLatencySample *sample = self.dataSource.samples[index];
    CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;

    if (self.annotation) {
        [graph.plotAreaFrame.plotArea removeAnnotation:self.annotation];
        self.annotation = nil;
        if (self.annotationIndex == index) {
            return;
        }
    }

    self.annotationIndex = index;

    NSNumber *y = sample.latency;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:3];
    NSString *yString = [formatter stringFromNumber:y];
    
    // Setup a style for the annotation
    CPTMutableTextStyle *hitAnnotationTextStyle = [CPTMutableTextStyle textStyle];
    hitAnnotationTextStyle.color    = [CPTColor whiteColor];
    hitAnnotationTextStyle.fontSize = 12.0;
    hitAnnotationTextStyle.fontName = @"Helvetica";

    NSString *tag = [NSString stringWithFormat:@"%@ %@", sample.identifier, yString];
    CPTTextLayer *textLayer = [[CPTTextLayer alloc] initWithText:tag
                                                           style:hitAnnotationTextStyle];
    textLayer.fill = [CPTFill fillWithColor:[CPTColor colorWithGenericGray:0.25]];
    NSArray *anchorPoint = [NSArray arrayWithObjects:sample.identifier, y, nil];

    // Now add the annotation to the plot area
    self.annotation = [[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:graph.defaultPlotSpace anchorPlotPoint:anchorPoint];
    self.annotation.contentLayer = textLayer;
    self.annotation.displacement = CGPointMake(0.0, -20.0);
    
    [graph.plotAreaFrame.plotArea addAnnotation:self.annotation];
}

- (void)legend:(CPTLegend *)legend legendEntryForPlot:(CPTPlot *)plot wasSelectedAtIndex:(NSUInteger)idx
{
    plot.hidden = ! plot.hidden;
}

#pragma mark - Tab Gesture Methods

- (void)handleTap:(UITapGestureRecognizer *)sender
{
    self.hostedGraph.legend.hidden = ! self.hostedGraph.legend.hidden;
}

@end
