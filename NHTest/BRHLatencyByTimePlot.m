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

@property (strong, nonatomic) NSArray *dataSource;
@property (strong, nonatomic) CPTPlotSpaceAnnotation *annotation;
@property (assign, nonatomic) NSUInteger annotationIndex;

- (void)makePlot;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
- (void)update:(NSNotification *)notification;
- (void)updateBounds;
- (void)updateTitle:(NSString *)title emitInterval:(NSInteger)emitInterval;
- (CPTPlotRange *)getYRangeInViewRange;


@end

@implementation BRHLatencyByTimePlot

- (void)useDataSource:(NSArray *)dataSource title:(NSString *)title emitInterval:(NSNumber *)emitInterval
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

    [self updateTitle:title emitInterval:emitInterval.integerValue];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHRunDataNewDataNotification object:nil];
}

- (void)dealloc
{
    BRHUserSettings *settings = [BRHUserSettings userSettings];
    [settings removeObserver:self forKeyPath:@"emitIntervalSetting"];
}

- (void)updateTitle:(NSString *)title emitInterval:(NSInteger)emitInterval
{
    CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.title = [NSString stringWithFormat:@"%@ - %lds Intervals", title, (long)emitInterval];
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

    x.axisLineStyle = nil;
    x.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];     // Keep the X axis from moving up/down when scrolling

    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    x.labelTextStyle = labelTextStyle;
    x.labelOffset = -4.0;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:2];
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

#if 0
    int counter = 0;
    NSMutableArray *ds = (NSMutableArray *)self.dataSource;
    for (int i = 0; i < 30; ++i) {
        for (int j = 0; j < 55; ++j) {
            BRHLatencyValue *stat = [BRHLatencyValue new];
            stat.identifier = [NSNumber numberWithInt:counter++];
            stat.when = [NSNumber numberWithDouble:counter];
            stat.value = [NSNumber numberWithDouble:(sin(j/55.0*3.14159) + 1.0) * i * 0.1];
            stat.average = [NSNumber numberWithDouble:2.5];
            stat.median = [NSNumber numberWithDouble:1.4];
            [ds addObject:stat];
        }
    }

//    [self updateBounds];
#endif
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateBounds];
}

- (int)calculatePlotWidth
{
    float w = self.hostedGraph.frame.size.width;
    return floor(w / (kPlotSymbolSize * 1.5));
}

- (void)handleTap:(UITapGestureRecognizer *)sender
{
    self.hostedGraph.legend.hidden = ! self.hostedGraph.legend.hidden;
}

- (void)redraw
{
    [self.hostedGraph.allPlots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL* stop) {
        [obj setDataNeedsReloading];
    }];
    [self updateBounds];
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

- (void)updateBounds
{
    int visiblePoints = [self calculatePlotWidth];

    NSArray *plotData = self.dataSource;
    NSInteger xMin = 0;
    NSInteger xMax = 0;
    CPTPlotRange *yRange = [self getYRangeInViewRange];

    if (plotData.count == 0) {
        xMax = visiblePoints - 1;
    }
    else {
        BRHLatencySample *tmp = [plotData lastObject];
        xMax = tmp.identifier.integerValue;
        if (xMax < visiblePoints) xMax = visiblePoints - 1;
        xMin = xMax - visiblePoints + 1;
        if (xMin < 0) xMin = 0;
    }

    NSDecimal xMin1 = CPTDecimalFromDouble(0.0 - 0.5);
    NSDecimal xMax1 = CPTDecimalFromDouble(xMax + 1.0);

    CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;

    plotSpace.globalXRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:xMax1];
    
    if (xMax < visiblePoints || xMax < plotSpace.xRange.endDouble + 2) {
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(xMin - 0.5) length:CPTDecimalFromDouble(visiblePoints)];
    }
    else {
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInteger(xMin) length:CPTDecimalFromInteger(xMax-xMin + 1)];
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
    NSArray *plotData = self.dataSource;
    NSUInteger numLatencies = plotData.count;
    for (CPTPlot* plot in [theGraph allPlots]) {
        [plot insertDataAtIndex:numLatencies - 1 numberOfRecords:1];
    }

    [self updateBounds];
}

#pragma mark Data Source Methods

- (NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return self.dataSource.count;
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = [NSDecimalNumber zero];
    NSString *key = nil;
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            key = @"identifier";
            break;

        case CPTScatterPlotFieldY:
            key = (NSString *)plot.identifier;
            break;

        default:
            break;
    }
        
    if (key != nil && index < self.dataSource.count) {
        num = [[self.dataSource objectAtIndex:index] valueForKey:key];
    }

    return num;
}

#pragma mark -
#pragma mark Plot Space Delegate Methods

- (CPTPlotRange *)getYRangeInViewRange
{
    double dmaxy = 0.0;
    double dminy = 0.0;
    NSArray *latencies = self.dataSource;

    if (latencies.count > 0) {
        dminy = 1e9;
        CPTXYGraph *theGraph = (CPTXYGraph *)self.hostedGraph;
        CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;

        NSUInteger xMin = MAX(0, floor(plotSpace.xRange.locationDouble));
        NSUInteger xMax = MIN(latencies.count - 1, plotSpace.xRange.endDouble);
        while (xMin <= xMax) {
            BRHLatencySample *sample = [latencies objectAtIndex:xMin++];
            if (sample.latency.doubleValue > dmaxy) {
                dmaxy = sample.latency.doubleValue;
            }

            if (sample.latency.doubleValue < dminy) {
                dminy = sample.latency.doubleValue;
            }
        }
    }

    dminy = ceil(10.0 * (dminy - 0.5)) / 10.0;
    dmaxy = floor(10.0 * (dmaxy + 0.5)) / 10.0;

    return [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(dminy) length:CPTDecimalFromDouble(dmaxy - dminy)];
}

- (void)updateYScale
{
    CPTPlotRange *yMinMax = [self getYRangeInViewRange];

    CPTXYGraph *theGraph = (CPTXYGraph *)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)theGraph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    CPTXYAxis *y = axisSet.yAxis;

    plotSpace.globalYRange = yMinMax;
    plotSpace.yRange = yMinMax;
    y.visibleAxisRange = yMinMax;
    y.visibleRange = yMinMax;
    x.gridLinesRange = yMinMax;
}

- (void)plotSpace:(CPTPlotSpace *)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateX) {
        
        // Clear any annotation that is no longer visible
        //
        if (self.annotation != nil) {
            CPTPlotRange *range = ((CPTXYPlotSpace *)space).xRange;
            BRHLatencySample *sample = [self.dataSource objectAtIndex:self.annotationIndex];
            if (! [range containsNumber:sample.identifier]) {
                CPTXYGraph *graph = (CPTXYGraph *)self.hostedGraph;
                [graph.plotAreaFrame.plotArea removeAnnotation:self.annotation];
                self.annotation = nil;
            }
        }

        [self updateYScale];
    }
}

#pragma mark -
#pragma mark Plot Delegate Methods

-(void)scatterPlot:(CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)index
{
    BRHLatencySample *sample = [self.dataSource objectAtIndex: index];
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

@end
