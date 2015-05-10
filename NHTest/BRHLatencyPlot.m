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
static double const kPlotSymbolSpan = kPlotSymbolSize + 5.0;

@interface BRHLatencyPlot () <CPTPlotDataSource, CPTPlotSpaceDelegate>

@property (nonatomic, weak) NSArray *dataSource;
@property (nonatomic, strong) CPTPlotSpaceAnnotation *latencyAnnotation;
@property (nonatomic, assign) NSUInteger latencyAnnotationIndex;
@property (nonatomic, assign) double maxPoints;
@property (nonatomic, assign) double xScaleFactor;

- (void)makeLatencyPlot;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
- (void)update:(NSNotification *)notification;
- (void)updateYScale:(NSTimer *)timer;

@end

@implementation BRHLatencyPlot

- (void)initialize:(BRHNotificationDriver *)driver
{
    // Establish linkages
    //
    self.dataSource = driver.latencies;
    [self makeLatencyPlot];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHNotificationDriverReceivedNotification object:driver];
}

- (void)makeLatencyPlot
{
    CPTXYGraph *graph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
    self.hostedGraph = graph;
    
    [graph applyTheme:[CPTTheme themeNamed:kCPTDarkGradientTheme]];

    // Plot space
    //
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.identifier = kLatenciesPlot;
    plotSpace.globalXRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInteger(0) length:CPTDecimalFromInteger(5)];
    plotSpace.xRange = plotSpace.globalXRange;
    plotSpace.globalYRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInteger(0) length:CPTDecimalFromInteger(2)];
    plotSpace.yRange = plotSpace.globalYRange;

    plotSpace.allowsUserInteraction = YES;
    plotSpace.allowsMomentumX = YES;
    plotSpace.allowsMomentumY = NO;
    // plotSpace.bounceAcceleration = 0.0;
    plotSpace.delegate = self;
    
    // No padding
    //
    graph.paddingLeft = 0.0f;
    graph.paddingRight = 0.0f;
    graph.paddingTop = 0.0f;
    graph.paddingBottom = 0.0f;
    
    // In plot area leave room for X and Y labels
    //
    graph.plotAreaFrame.borderLineStyle = nil;
    graph.plotAreaFrame.cornerRadius = 0.0f;
    graph.plotAreaFrame.paddingLeft = 40.0;
    graph.plotAreaFrame.paddingTop = 8.0;
    graph.plotAreaFrame.paddingRight = 10.0;
    graph.plotAreaFrame.paddingBottom = 35.0;
    
    // Grid line styles
    //
    CPTMutableLineStyle *majorGridLineStyle = [CPTMutableLineStyle lineStyle];
    majorGridLineStyle.lineWidth = 0.75;
    majorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.5] colorWithAlphaComponent:0.75];
    
    CPTMutableLineStyle *minorGridLineStyle = [CPTMutableLineStyle lineStyle];
    minorGridLineStyle.lineWidth = 0.25;
    minorGridLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:0.1];
    
    // Label style
    //
    CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor colorWithGenericGray:0.75];
    textStyle.fontSize = 13.0f;
    
    // Setup axes
    //
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    
    // X axis
    //
    x.labelOffset = 0.0;
    x.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    // x.visibleRange = plotSpace.globalXRange;
    x.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];     // Keep the X axis from moving up/down when scrolling
    x.majorGridLineStyle = majorGridLineStyle;
    x.minorGridLineStyle = nil;
    x.minorTicksPerInterval = 0;

    x.labelTextStyle = textStyle;
    x.majorIntervalLength = CPTDecimalFromInt(10);
    x.majorTickLineStyle = nil;
    x.titleTextStyle = textStyle;

    x.title = @"Notification Latencies";
    x.titleOffset = 18.0f;

    // We have our own way of formatting the elapsed times at the bottom
    //
    BRHTimeFormatter *formatter = [[BRHTimeFormatter alloc] init];
    x.labelFormatter = formatter;

    // Y axis
    //
    CPTXYAxis *y = axisSet.yAxis;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.axisConstraints = [CPTConstraints constraintWithLowerOffset:0.0];     // Keep the Y axis from moving left/right when scrolling
    y.majorGridLineStyle = majorGridLineStyle;
    y.minorGridLineStyle = minorGridLineStyle;
    
    y.labelTextStyle = textStyle;
    y.labelOffset = 5.0;
    y.majorTickLineStyle = nil;
    y.minorTicksPerInterval = 0;
    
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
    plot.plotSymbolMarginForHitDetection = 10.0;
    
    [graph addPlot:plot];
    
    // Legend
    //
    CPTLegend *legend = [CPTLegend legendWithGraph:graph];
    graph.legend = legend;
    legend.hidden = YES;
    legend.fill = [CPTFill fillWithColor:[[CPTColor darkGrayColor] colorWithAlphaComponent:0.5]];
    legend.textStyle = textStyle;
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

- (void)update:(NSNotification*)notification
{
    CPTXYGraph *theGraph = (CPTXYGraph*)self.hostedGraph;
    if (theGraph == nil) return;

    BRHLatencyValue *data = notification.userInfo[@"value"];

    // Add a new value to the plots, causing them to fetch a new value from the data source
    //
    NSArray *plotData = self.dataSource;
    NSUInteger numLatencies = plotData.count;
    for (CPTPlot *plot in [theGraph allPlots]) {
        [plot insertDataAtIndex:plot.cachedDataCount numberOfRecords:numLatencies - plot.cachedDataCount];
    }

    // Update X scale
    //
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)theGraph.defaultPlotSpace;
    double x = data.when.doubleValue;

    if (numLatencies == 1) {
        CPTPlot *plot = self.hostedGraph.allPlots[0];
        double frameWidth = plot.frame.size.width;
        self.maxPoints = floor(frameWidth / kPlotSymbolSpan);
    }
    else {

        // For subsequent points, track the average MIN spacing between points and use that to calculate
        // the MAX number of points we should show on the plot.
        //
        BRHLatencyValue *prev = [self.dataSource objectAtIndex:numLatencies - 2];
        double delta = self.xScaleFactor = (x - prev.when.doubleValue);
        if (numLatencies < 10){
            self.xScaleFactor = MIN(self.xScaleFactor, (delta + (numLatencies - 1) * self.xScaleFactor) / numLatencies);
        }

        double xMin = plotSpace.globalXRange.locationDouble;

        // Adjust the plot view so that the X (time) value is completely visible when plotted
        //
        x += 0.5 * self.xScaleFactor;

        // Extend the global range so we can see it.
        //
        plotSpace.globalXRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(xMin)
                                                              length:CPTDecimalFromDouble(x - xMin)];
        if (numLatencies < self.maxPoints) {
            
            // Just grow the range, shrinking the spacing between points
            //
            plotSpace.xRange = plotSpace.globalXRange;
        }
        else {
            
            // At minimum desired spacing. Scroll if the current plot view is near to the end of the plot
            //
            double plotWidth = plotSpace.xRange.lengthDouble;
            if (plotSpace.xRange.endDouble + 2 * self.xScaleFactor >= x) {
                
                // Scroll to show the new point
                //
                double start = x - plotWidth;
                CPTPlotRange *newRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(start)
                                                                      length:CPTDecimalFromDouble(plotWidth)];
                plotSpace.xRange = newRange;
            }
        }
    }
}

- (CPTPlotRange*)calculateYRange
{
    CPTXYGraph *theGraph = (CPTXYGraph *)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)theGraph.defaultPlotSpace;
    double viewBegin = plotSpace.xRange.locationDouble;
    NSArray *latencies = self.dataSource;
    BRHLatencyValue *tmp = [BRHLatencyValue new];
    
    // Locate the data point that is closest to the view start
    //
    tmp.when = [NSNumber numberWithDouble:viewBegin];
    NSUInteger pos1 = [latencies indexOfObject:tmp inSortedRange:NSMakeRange(0, latencies.count) options:NSBinarySearchingInsertionIndex
                               usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                   return [((BRHLatencyValue*)obj1).when compare:((BRHLatencyValue*)obj2).when];
                               }];
    
    NSUInteger length = MIN(self.maxPoints, latencies.count);
    if (pos1 + length > latencies.count) {
        length = latencies.count - pos1;
    }
    
    NSNumber *maxy = [[latencies subarrayWithRange:NSMakeRange(pos1, length)] valueForKeyPath:@"@max.value"];
    double dmaxy = maxy.doubleValue;
    dmaxy = (int)((dmaxy + 3) / 2) * 2.0;
    
    return [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0.0)
                                        length:CPTDecimalFromDouble(dmaxy)];
}

- (void)updateYScale:(NSTimer*)timer;
{
    CPTPlotRange *newRange = [self calculateYRange];
    double dmaxy = newRange.endDouble;
    CPTXYGraph *theGraph = (CPTXYGraph*)self.hostedGraph;
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)theGraph.defaultPlotSpace;
    if (dmaxy < plotSpace.globalYRange.endDouble) {
        plotSpace.yRange = newRange;
        plotSpace.globalYRange = newRange;
    }
    else if (dmaxy > plotSpace.globalYRange.endDouble){
        plotSpace.globalYRange = newRange;
        plotSpace.yRange = newRange;
    }
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
            key = @"when";
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
        
    if (key != nil) {
        num = [[self.dataSource objectAtIndex:index] valueForKey:key];
    }
    
    return num;
}

#pragma mark -
#pragma mark Plot Space Delegate Methods

- (void)plotSpace:(CPTPlotSpace*)space didChangePlotRangeForCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateX) {
        if (self.latencyAnnotation != nil) {
            CPTPlotRange *range = ((CPTXYPlotSpace*)space).xRange;
            BRHLatencyValue *data = [self.dataSource objectAtIndex:self.latencyAnnotationIndex];
            if ([range containsDouble:data.when.doubleValue] == NO) {
                CPTXYGraph *graph = (CPTXYGraph*)self.hostedGraph;
                [graph.plotAreaFrame.plotArea removeAnnotation:self.latencyAnnotation];
                self.latencyAnnotation = nil;
            }
        }

        [[NSRunLoop mainRunLoop] cancelPerformSelector:@selector(updateYScale:) target:self argument:nil];
        [[NSRunLoop mainRunLoop] performSelector:@selector(updateYScale:) target:self argument:nil order:0 modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSRunLoopCommonModes, nil]];
    }
}

- (CPTPlotRange *)plotSpace:(CPTPlotSpace*)space willChangePlotRangeTo:(CPTPlotRange *)newRange forCoordinate:(CPTCoordinate)coordinate
{
    if (coordinate == CPTCoordinateX) {
        CPTPlotRange *maxRange = ((CPTXYPlotSpace*)space).globalXRange;
        CPTMutablePlotRange *changedRange = [newRange mutableCopy];
        [changedRange shiftEndToFitInRange:maxRange];
        [changedRange shiftLocationToFitInRange:maxRange];
        newRange = changedRange;
    }
    
    return newRange;
}

-(BOOL)plotSpace:(CPTPlotSpace *)space shouldScaleBy:(CGFloat)interactionScale aboutPoint:(CGPoint)interactionPoint
{
    return YES;
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
    hitAnnotationTextStyle.fontSize = 16.0;
    hitAnnotationTextStyle.fontName = @"Helvetica-Bold";
    
    CPTTextLayer *textLayer = [[CPTTextLayer alloc] initWithText:yString style:hitAnnotationTextStyle];
    NSArray *anchorPoint = [NSArray arrayWithObjects:data.when, y, nil];
    
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
