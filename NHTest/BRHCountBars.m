//
//  BRHCountBars.m
//
//  Created by Brad Howes on 12/21/13.
//  Copyright (c) 2013 Brad Howes. All rights reserved.
//

#import "BRHBinFormatter.h"
#import "BRHHistogram.h"
#import "BRHLogger.h"
#import "BRHCountBars.h"
#import "BRHNotificationDriver.h"

static NSString *const kHistogramPlot = @"Histogram";

@interface BRHCountBars () <CPTPlotDataSource, CPTBarPlotDelegate>

@property (nonatomic, weak) BRHHistogram *dataSource;
@property (nonatomic, strong) CPTPlotSpaceAnnotation *binAnnotation;
@property (nonatomic, assign) NSUInteger binAnnotationIndex;

- (void)makeHistogramPlot;
- (void)update:(NSNotification *)notification;

@end

@implementation BRHCountBars

- (void)initialize:(BRHNotificationDriver *)driver
{
    // Establish linkages
    //
    self.dataSource = driver.bins;
    [self makeHistogramPlot];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:BRHNotificationDriverReceivedNotification object:driver];
}

- (void)makeHistogramPlot
{
    NSUInteger numBins = self.dataSource.count;
    
    CPTXYGraph *graph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
    [graph applyTheme:[CPTTheme themeNamed:kCPTDarkGradientTheme]];
    
    graph.paddingTop = 0.0f;
    graph.paddingLeft = 0.0f;
    graph.paddingBottom = 0.0f;
    graph.paddingRight = 0.0f;
    
    graph.plotAreaFrame.borderLineStyle = nil;
    graph.plotAreaFrame.cornerRadius = 0.0f;

    graph.plotAreaFrame.paddingTop = 12.0;
    graph.plotAreaFrame.paddingLeft = 25.0;
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

    CPTMutableTextStyle *labelStyle = [CPTMutableTextStyle textStyle];
    labelStyle.color = [CPTColor colorWithGenericGray:0.75];
    labelStyle.fontSize = 12.0f;

    CPTMutableTextStyle *titleStyle = [CPTMutableTextStyle textStyle];
    titleStyle.color = [CPTColor colorWithGenericGray:0.75];
    titleStyle.fontSize = 11.0f;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)graph.defaultPlotSpace;
    plotSpace.identifier = kHistogramPlot;
    plotSpace.allowsUserInteraction = NO;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(-1) length:CPTDecimalFromInteger(numBins + 1)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromInteger(5)];

    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;

    // X Axis
    //
    CPTXYAxis *x = axisSet.xAxis;
    x.axisLineStyle = nil;
    x.titleTextStyle = titleStyle;
    x.labelTextStyle = labelStyle;
    x.majorTickLineStyle = tickLineStyle;
    x.minorTickLineStyle = tickLineStyle;

    x.majorIntervalLength = CPTDecimalFromInt(5);
    x.tickDirection = CPTSignNegative;
    x.majorTickLength = 5.0;
    x.minorTickLength = 5.0;
    x.minorTicksPerInterval = 4;

    CPTMutablePlotRange *range = [CPTMutablePlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromLongLong(numBins - 1)];
    x.visibleRange = range;
    x.gridLinesRange = range;

    x.labelFormatter = [BRHBinFormatter binFormatterWithMaxBins:numBins];
    x.labelOffset = -4.0;
    x.title = @"Histogram (1s bin)";
    x.titleOffset = 18.0;
    
    // Y Axis
    //
    CPTXYAxis *y = axisSet.yAxis;
    y.axisLineStyle = nil;
    y.labelTextStyle = labelStyle;
    y.majorTickLineStyle = tickLineStyle;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.preferredNumberOfMajorTicks = 5;
    y.minorTickLineStyle = nil;
    y.majorGridLineStyle = gridLineStyle;
    y.minorGridLineStyle = nil;

    y.majorTickLength = 8.0;
    y.tickDirection = CPTSignNegative;

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:0];
    formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:2];
    y.labelFormatter = formatter;
    y.labelOffset = 2.0;
    //y.labelExclusionRanges = [NSArray arrayWithObject:[CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromFloat(0.5)]];

    CPTBarPlot *plot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor cyanColor] horizontalBars:NO];
    // plot.fill = [CPTFill fillWithColor:[CPTColor whiteColor]];
    plot.barWidth = CPTDecimalFromFloat(0.7);
    plot.identifier = kHistogramPlot;
    plot.dataSource = self;
    plot.delegate = self;
    [graph addPlot:plot toPlotSpace:plotSpace];

    self.backgroundColor = [UIColor blackColor];
    self.hostedGraph = graph;

#if 0
    for (int z = 0; z < 13; ++z)
        [self.dataSource addValue:0.5];

    [self.dataSource addValue:1];
    [self.dataSource addValue:1];
    [self.dataSource addValue:1];

    [self.dataSource addValue:2];
    [self.dataSource addValue:2];
    [self.dataSource addValue:2];
    [self.dataSource addValue:2];
    [self.dataSource addValue:2];

    [self.dataSource addValue:28];
    [self.dataSource addValue:29];
    [self.dataSource addValue:30];
    [self.dataSource addValue:30];
    [self.dataSource addValue:31];
    [self.dataSource addValue:32];
    [self.dataSource addValue:33];
    [self.dataSource addValue:34];
    [self.dataSource addValue:35];

    // [plotSpace scaleToFitPlots: graph.allPlots];
#endif
}

- (void)clear
{
    [self.hostedGraph.allPlots enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj setDataNeedsReloading];
    }];
}

- (void)renderPDF:(CGContextRef)pdfContext
{
    CPTLayer *graph = self.hostedGraph;
    CGRect mediaBox = CPTRectMake(0, 0, graph.bounds.size.width, graph.bounds.size.height);
    CGContextBeginPage(pdfContext, &mediaBox);
    [graph layoutAndRenderInContext:pdfContext];
    CGContextEndPage(pdfContext);
}

- (void)refreshDisplay
{
    [self.hostedGraph reloadData];
}

- (void)update:(NSNotification*)notification
{
    NSUInteger bin = [notification.userInfo[@"bin"] unsignedIntegerValue];
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)self.hostedGraph.defaultPlotSpace;
    [self.hostedGraph.allPlots[0] reloadDataInIndexRange:NSMakeRange(bin, 1)];

    NSUInteger count = [[self.dataSource binAtIndex:bin] unsignedIntegerValue];
    count = MAX((count / 5 + 1) * 5, 5);
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(0) length:CPTDecimalFromInteger(count)];
    
    if (self.binAnnotation != nil && self.binAnnotationIndex == bin) {
        CPTTextLayer *textLayer = (CPTTextLayer*)self.binAnnotation.contentLayer;
        textLayer.text = [NSString stringWithFormat:@"%ld", (unsigned long)count];
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
    
    switch (fieldEnum) {
        case CPTBarPlotFieldBarLocation:
            num = [NSNumber numberWithUnsignedInteger:index];
            break;
                
        case CPTBarPlotFieldBarTip:
            num = [self.dataSource binAtIndex:index];
            break;
                
        default:
            break;
    }
    
    return num;
}

#pragma mark -
#pragma mark Plot Space Delegate Methods

-(BOOL)plotSpace:(CPTPlotSpace *)space shouldScaleBy:(CGFloat)interactionScale aboutPoint:(CGPoint)interactionPoint
{
    return NO;
}

#pragma mark -
#pragma mark Plot Delegate Methods

- (void)barPlot:(CPTBarPlot*)plot barWasSelectedAtRecordIndex:(NSUInteger)index
{
    if (self.binAnnotation != nil) {
        [self.hostedGraph.plotAreaFrame.plotArea removeAnnotation:self.binAnnotation];
        self.binAnnotation = nil;
        if (index == self.binAnnotationIndex) {
            return;
        }
    }
    
    self.binAnnotationIndex = index;
    
    // Setup a style for the annotation
    CPTMutableTextStyle *hitAnnotationTextStyle = [CPTMutableTextStyle textStyle];
    hitAnnotationTextStyle.color    = [CPTColor whiteColor];
    hitAnnotationTextStyle.fontSize = 16.0;
    hitAnnotationTextStyle.fontName = @"Helvetica-Bold";
    
    CPTTextLayer *textLayer = [[CPTTextLayer alloc] initWithText:[NSString stringWithFormat:@"%ld", (long)[[self.dataSource binAtIndex:index] integerValue]] style:hitAnnotationTextStyle];
    NSNumber *x = [NSNumber numberWithInteger:index];
    NSNumber *y = [NSNumber numberWithInteger:0];
    NSArray *anchorPoint = [NSArray arrayWithObjects:x, y, nil];
    
    self.binAnnotation = [[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:plot.plotSpace anchorPlotPoint:anchorPoint];
    self.binAnnotation.contentLayer = textLayer;
    self.binAnnotation.displacement = CGPointMake(-0.5, 10.0);
    
    [self.hostedGraph.plotAreaFrame.plotArea addAnnotation:self.binAnnotation];
}

@end
