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

    graph.plotAreaFrame.paddingTop = 8.0;
    graph.plotAreaFrame.paddingLeft = 25.0;
    graph.plotAreaFrame.paddingBottom = 35.0;
    graph.plotAreaFrame.paddingRight = 10.0;
    
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    axisLineStyle.lineWidth = 2.0;
    axisLineStyle.lineColor = [[CPTColor grayColor] colorWithAlphaComponent:1.0];
    
    CPTMutableLineStyle *majorGridLineStyle = [CPTMutableLineStyle lineStyle];
    majorGridLineStyle.lineWidth = 0.75;
    majorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:0.5] colorWithAlphaComponent:0.75];
    
    CPTMutableLineStyle *minorGridLineStyle = [CPTMutableLineStyle lineStyle];
    minorGridLineStyle.lineWidth = 0.25;
    minorGridLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:0.1];
    
    CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor colorWithGenericGray:0.75];
    textStyle.fontSize = 13.0f;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace*)graph.defaultPlotSpace;
    plotSpace.identifier = kHistogramPlot;
    plotSpace.allowsUserInteraction = NO;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(-0.5f) length:CPTDecimalFromInteger(numBins)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInteger(0) length:CPTDecimalFromInteger(5)];

    CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
    CPTXYAxis *x = axisSet.xAxis;
    x.axisLineStyle = axisLineStyle;
    x.titleTextStyle = textStyle;
    x.labelTextStyle = textStyle;
    x.majorIntervalLength = CPTDecimalFromInt(5);
    x.minorTicksPerInterval = 0;
    x.majorGridLineStyle = nil;
    x.majorTickLength = 0.0;
    x.visibleRange   = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.0f) length:CPTDecimalFromFloat(numBins + 1)];
    x.gridLinesRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.0f) length:CPTDecimalFromFloat(numBins + 1)];
    

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:0];
    x.labelFormatter = formatter;
    x.title = @"Histogram (1s bin)";
    x.titleOffset = 18.0f;
    x.majorTickLineStyle = nil;
    
    // We have our own way of formatting the elapsed times at the bottom
    //
    x.labelFormatter = [BRHBinFormatter binFormatterWithMaxBins:numBins];

    CPTXYAxis *y = axisSet.yAxis;
    y.axisLineStyle = axisLineStyle;
    y.tickDirection = CPTSignNegative;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.titleTextStyle = textStyle;
    y.labelTextStyle = textStyle;
    y.majorGridLineStyle = majorGridLineStyle;
    y.minorGridLineStyle = nil;
    y.minorTickLineStyle = nil;
    y.majorTickLineStyle = nil;
    y.majorTickLength = 0.0;
    y.labelOffset = 12.0;
    y.visibleRange   = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.0f) length:CPTDecimalFromFloat(numBins + 1)];
    y.gridLinesRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(0.0f) length:CPTDecimalFromFloat(numBins + 1)];
    
    formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:2];
    y.labelFormatter = formatter;
    y.title = @"Counts";
    y.titleOffset = 25.0f;
    y.axisLineStyle = nil;
    
    CPTBarPlot *plot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor cyanColor] horizontalBars:NO];
    plot.barWidth = CPTDecimalFromFloat(0.7);
    //plot.barOffset = CPTDecimalFromFloat(0.0);
    plot.identifier = kHistogramPlot;
    plot.dataSource = self;
    plot.delegate = self;
    [graph addPlot:plot toPlotSpace:plotSpace];
    
    self.backgroundColor = [UIColor blackColor];
//    self.countBars.collapsesLayers = YES;
    self.hostedGraph = graph;
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
    if ([plotSpace.yRange compareToNumber:@(count)] != CPTPlotRangeComparisonResultNumberInRange) {
        plotSpace.globalYRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(0) length:CPTDecimalFromUnsignedInteger(MAX(count, 5))];
        plotSpace.yRange = plotSpace.globalYRange;
    }

    // Update any visible bin annotiation with the latest value
    //
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
