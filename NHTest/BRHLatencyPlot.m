//
//  BRHLatencyPlot.m
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import "BRHLatencyValue.h"
#import "BRHLogger.h"
#import "BRHLatencyPlot.h"
#import "BRHNotificationDriver.h"
#import "BRHTimeFormatter.h"

static NSString *const kLatenciesPlot = @"Latency";
static NSString *const kAveragePlot = @"Avg";
static NSString *const kMedianPlot = @"Mdn";
static NSString *const kHistogramPlot = @"Histogram";

static double const kPlotSymbolSize = 10.0;

@interface BRHLatencyPlot () <CPTPlotDataSource, CPTPlotSpaceDelegate>

@property (nonatomic, weak) NSArray *dataSource;
@property (nonatomic, strong) CPTPlotSpaceAnnotation *latencyAnnotation;
@property (nonatomic, assign) NSUInteger latencyAnnotationIndex;
@property (nonatomic, assign) double maxPoints;
@property (nonatomic, assign) double xScaleFactor;

- (void)makeLatencyPlot;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
- (void)update:(NSNotification *)notification;
- (void)orientationChanged:(NSNotification *)notification;

@end

@implementation BRHLatencyPlot

- (void)initialize:(BRHNotificationDriver *)driver
{
    // Establish linkages
    //
    self.dataSource = driver.latencies;
    [self makeLatencyPlot];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHNotificationDriverReceivedNotification object:driver];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification  object:nil];
}

- (void)makeLatencyPlot
{
    CPTXYGraph *graph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
    self.hostedGraph = graph;
    [graph applyTheme:[CPTTheme themeNamed:kCPTDarkGradientTheme]];

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
    gridLineStyle.lineColor = [CPTColor colorWithGenericGray:0.45];
    
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
    plotSpace.identifier = kLatenciesPlot;
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
    x.title = @"Notification Latencies";
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
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.majorGridLineStyle = gridLineStyle;
    y.minorGridLineStyle = nil;

    y.labelTextStyle = labelTextStyle;
    y.labelOffset = 0.0;
    y.majorTickLineStyle = nil;
    y.minorTickLineStyle = nil;
    y.tickDirection = CPTSignNone;

    y.axisLineStyle = nil;
    y.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];

    CPTScatterPlot *plot;

    // Average plot
    //
    plot = [[CPTScatterPlot alloc] init];
    plot.identifier = kAveragePlot;
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
    plot.identifier = kMedianPlot;
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
    plot.identifier = kLatenciesPlot;
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
    plot.plotSymbolMarginForHitDetection = 20.0;
    
    [graph addPlot:plot];
    
    // Legend
    //
    CPTLegend *legend = [CPTLegend legendWithGraph:graph];
    graph.legend = legend;
    legend.hidden = YES;
    legend.fill = [CPTFill fillWithColor:[[CPTColor darkGrayColor] colorWithAlphaComponent:0.5]];
    legend.textStyle = titleTextStyle;
    legend.borderLineStyle = x.axisLineStyle;
    NSLog(@"%f %@", x.axisLineStyle.lineWidth, [[UIColor colorWithCGColor:x.axisLineStyle.lineColor.cgColor] description]);
    legend.cornerRadius = 5.0;
    legend.swatchSize = CGSizeMake(25.0, 25.0);
    legend.numberOfRows = 1;
    legend.delegate = self;
    graph.legendAnchor = CPTRectAnchorTop;
    graph.legendDisplacement = CGPointMake(0.0, 0.0);
    
    self.backgroundColor = [UIColor blackColor];
    //    self.latencyPlot.collapsesLayers = YES;
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];

    recognizer.numberOfTouchesRequired = 1;
    recognizer.numberOfTapsRequired = 2;
    [self addGestureRecognizer:recognizer];

#if 0
    NSMutableArray* ds = (NSMutableArray*)self.dataSource;
    for (int i = 0; i < 52; ++i) {
        BRHLatencyValue *stat = [BRHLatencyValue new];
        stat.identifier = [NSNumber numberWithInt:i];
        stat.when = [NSNumber numberWithDouble:i];
        stat.value = [NSNumber numberWithDouble:1.3];
        stat.average = [NSNumber numberWithDouble:2.5];
        stat.median = [NSNumber numberWithDouble:1.4];
        
        [ds addObject:stat];
    }

    CPTPlot *p = (CPTPlot*)(graph.allPlots[0]);
    CPTPlotArea* area = p.plotArea;
    NSLog(@"masksToBorder: %d", area.masksToBorder);
    NSLog(@"masksToBounds: %d", area.masksToBounds);
    area.masksToBorder = NO;
    area.masksToBounds = NO;
#endif

    [self updateBounds];
    [self updateYScale:nil];
}

- (int)calculatePlotWidth
{
    float w = self.hostedGraph.frame.size.width;
    return floor(w / (kPlotSymbolSize * 1.75));
}

- (void)handleTap:(UITapGestureRecognizer *)sender
{
    self.hostedGraph.legend.hidden = ! self.hostedGraph.legend.hidden;
}

- (void)clear
{
    [self.hostedGraph.allPlots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj setDataNeedsReloading];
    }];
}

- (void)renderPDF:(CGContextRef)pdfContext
{
    CPTXYGraph *graph = (CPTXYGraph*)self.hostedGraph;

    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)graph.defaultPlotSpace;
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

- (void)refreshDisplay
{
    [self.hostedGraph reloadData];
}

- (void)updateBounds
{
    int visiblePoints = [self calculatePlotWidth];

    NSArray *plotData = self.dataSource;
    NSInteger xMin = 0;
    NSInteger xMax;
    double yMax;

    if (plotData.count == 0) {
        xMax = visiblePoints;
        yMax = 2.0;
    }
    else {
        BRHLatencyValue* v = [plotData lastObject];
        xMax = v.identifier.integerValue;
        xMin = xMax - visiblePoints;
        if (xMin < 0) {
            xMin = 0;
        }

        NSRange span = NSMakeRange(xMin, xMax - xMin + 1);
        NSNumber* tmp = [[plotData subarrayWithRange:span] valueForKeyPath:@"@max.value"];
        yMax = floor(tmp.doubleValue + 1.9);
        // yMax = (int)((tmp.doubleValue + 3) / 2) * 2.0;
    }

    if (xMax < visiblePoints) {
        xMax = visiblePoints;
    }

    NSDecimal xMin1 = CPTDecimalFromDouble(0.0 - 0.5);
    NSDecimal xMax1 = CPTDecimalFromDouble(xMax + 1.0);

    CPTXYGraph *graph = (CPTXYGraph*)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)graph.defaultPlotSpace;

    plotSpace.globalXRange = [CPTPlotRange plotRangeWithLocation:xMin1 length:xMax1];
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(xMin - 0.5) length:CPTDecimalFromDouble(visiblePoints + 1.0)];

    CPTPlotRange *yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(yMax)];
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

- (void)orientationChanged:(NSNotification *)notification
{
    [self updateBounds];
}

- (void)update:(NSNotification*)notification
{
    CPTXYGraph *theGraph = (CPTXYGraph*)self.hostedGraph;
    if (theGraph == nil) return;

    // Add a new value to the plots, causing them to fetch a new value from the data source
    //
    NSArray *plotData = self.dataSource;
    NSUInteger numLatencies = plotData.count;
    for (CPTPlot *plot in [theGraph allPlots]) {
        [plot insertDataAtIndex:numLatencies - 1 numberOfRecords:1];
    }

    [self updateBounds];
}

#pragma mark Data Source Methods

- (NSUInteger)numberOfRecordsForPlot:(CPTPlot*)plot
{
    return self.dataSource.count;
}

-(NSNumber*)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = [NSDecimalNumber zero];
    NSString *key = nil;
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            key = @"identifier";
            break;

        case CPTScatterPlotFieldY:
            if (plot.identifier == kLatenciesPlot) {
                key = @"value";
            }
            else if (plot.identifier == kAveragePlot) {
                key = @"average";
            }
            else {
                key = @"median";
            }
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

- (double)getMaxYInViewRange
{
    double dmaxy = 2.0;
    NSArray *latencies = self.dataSource;

    if (latencies.count > 0) {
        CPTXYGraph *theGraph = (CPTXYGraph *)self.hostedGraph;
        CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
        int visiblePoints = [self calculatePlotWidth];

        int pos2 = plotSpace.xRange.endDouble;
        if (pos2 >= latencies.count) pos2 = latencies.count - 1;

        int pos1 = pos2 - visiblePoints + 1;
        if (pos1 < 0) pos1 = 0;

        NSNumber *maxy = [[latencies subarrayWithRange:NSMakeRange(pos1, pos2 - pos1 + 1)] valueForKeyPath:@"@max.value"];
        dmaxy = maxy.doubleValue;
        dmaxy = floor(dmaxy + 1.9);
    }

    return dmaxy;
}

- (void)updateYScale:(NSTimer*)timer;
{
    double dmaxy = [self getMaxYInViewRange];

    [[NSRunLoop mainRunLoop] cancelPerformSelector:@selector(updateYScale:) target:self argument:nil];

    CPTXYGraph *theGraph = (CPTXYGraph*)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)theGraph.defaultPlotSpace;
    CPTPlotRange *newRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0) length:CPTDecimalFromDouble(dmaxy)];

    if (dmaxy < plotSpace.globalYRange.endDouble) {
        plotSpace.globalYRange = newRange;
        plotSpace.yRange = newRange;
    }
    else if (dmaxy > plotSpace.globalYRange.endDouble){
        plotSpace.globalYRange = newRange;
        plotSpace.yRange = newRange;
    }
}

- (void)plotSpace:(CPTPlotSpace*)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateX) {
        
        // Clear any annotation that is no longer visible
        //
        if (self.latencyAnnotation != nil) {
            CPTPlotRange *range = ((CPTXYPlotSpace*)space).xRange;
            BRHLatencyValue *data = [self.dataSource objectAtIndex:self.latencyAnnotationIndex];
            if ([range containsDouble:data.when.doubleValue] == NO) {
                CPTXYGraph *graph = (CPTXYGraph*)self.hostedGraph;
                [graph.plotAreaFrame.plotArea removeAnnotation:self.latencyAnnotation];
                self.latencyAnnotation = nil;
            }
        }
        
        // Update the Y scaling
        //
        [[NSRunLoop mainRunLoop] cancelPerformSelector:@selector(updateYScale:) target:self argument:nil];
        [[NSRunLoop mainRunLoop] performSelector:@selector(updateYScale:) target:self argument:nil order:0 modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSRunLoopCommonModes, nil]];
    }
}

#pragma mark -
#pragma mark Plot Delegate Methods

-(void)scatterPlot:(CPTScatterPlot *)plot plotSymbolWasSelectedAtRecordIndex:(NSUInteger)index
{
    BRHLatencyValue *data = [self.dataSource objectAtIndex: index];
    CPTXYGraph *graph = (CPTXYGraph*)self.hostedGraph;
    
    if (self.latencyAnnotation) {
        [graph.plotAreaFrame.plotArea removeAnnotation:self.latencyAnnotation];
        self.latencyAnnotation = nil;
        if (self.latencyAnnotationIndex == index) {
            return;
        }
    }

    self.latencyAnnotationIndex = index;

    NSNumber *y = data.value;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:3];
    NSString *yString = [formatter stringFromNumber:y];
    
    // Setup a style for the annotation
    CPTMutableTextStyle *hitAnnotationTextStyle = [CPTMutableTextStyle textStyle];
    hitAnnotationTextStyle.color    = [CPTColor whiteColor];
    hitAnnotationTextStyle.fontSize = 14.0;
    hitAnnotationTextStyle.fontName = @"Helvetica-Bold";

    CPTTextLayer *textLayer = [[CPTTextLayer alloc] initWithText:[NSString stringWithFormat:@"%@: %@", data.identifier, yString] style:hitAnnotationTextStyle];
    textLayer.fill = [CPTFill fillWithColor:[CPTColor colorWithGenericGray:0.25]];
    NSArray *anchorPoint = [NSArray arrayWithObjects:data.identifier, y, nil];

    // Now add the annotation to the plot area
    self.latencyAnnotation = [[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:graph.defaultPlotSpace anchorPlotPoint:anchorPoint];
    self.latencyAnnotation.contentLayer = textLayer;
    self.latencyAnnotation.displacement = CGPointMake(0.0, -20.0);
    
    [graph.plotAreaFrame.plotArea addAnnotation:self.latencyAnnotation];
}

- (void)legend:(CPTLegend *)legend legendEntryForPlot:(CPTPlot *)plot wasSelectedAtIndex:(NSUInteger)idx
{
    plot.hidden = ! plot.hidden;
}

@end
