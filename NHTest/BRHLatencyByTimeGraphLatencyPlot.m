// BRHLatencyByTimeGraphLatencyPlot.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimeGraph.h"
#import "BRHLatencyByTimeGraphLatencyPlot.h"
#import "BRHLatencySample.h"
#import "BRHRunData.h"

static double const kPlotSymbolSize = 8.0;

@implementation BRHLatencyByTimeGraphLatencyPlot

+ (instancetype)plotFor:(BRHLatencyByTimeGraph *)graph
{
    return [[BRHLatencyByTimeGraphLatencyPlot alloc] initFor:graph];
}

- (instancetype)initFor:(BRHLatencyByTimeGraph *)graph
{
    if (self = [super initFor:graph]) {
        self.sampleValueKey = @"latency";
    }

    return self;
}

- (CPTScatterPlot *)makePlot
{
    CPTScatterPlot *plot = [[CPTScatterPlot alloc] init];
    plot.identifier = @"Latency";
    plot.dataSource = self;
    
    plot.cachePrecision = CPTPlotCachePrecisionDouble;
    
    CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 1.0f;
    lineStyle.lineColor = [CPTColor grayColor];
    plot.dataLineStyle = lineStyle;

    CPTGradient *symbolGradient = [CPTGradient gradientWithBeginningColor:[CPTColor colorWithComponentRed:0.75 green:0.75 blue:1.0 alpha:1.0]
                                                              endingColor:[CPTColor cyanColor]];
    symbolGradient.gradientType = CPTGradientTypeRadial;
    symbolGradient.startAnchor  = CPTPointMake(0.25, 0.75);
    
    CPTPlotSymbol *plotSymbol = [CPTPlotSymbol ellipsePlotSymbol];
    plotSymbol.fill = [CPTFill fillWithGradient:symbolGradient];
    plotSymbol.lineStyle = nil;
    plotSymbol.size = CGSizeMake(kPlotSymbolSize, kPlotSymbolSize);
    plot.plotSymbol = plotSymbol;
    plot.plotSymbolMarginForHitDetection = kPlotSymbolSize * 1.5;

    return plot;
}

- (NSArray *)dataSource
{
    return self.runData.samples;
    return nil;
}

- (NSRange)getUpdateRangeFrom:(BRHRunDataNotificationInfo *)info
{
    return NSMakeRange(info.sampleIndex, info.sampleCount);
}

#pragma mark - Plot Delegate Methods

#if 0

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

#endif

@end
