// BRHLatencyByTimeGraphAveragePlot.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimeGraphMissingPlot.h"
#import "BRHLatencySample.h"
#import "BRHRunData.h"

static double const kPlotSymbolSize = 8.0;

@implementation BRHLatencyByTimeGraphMissingPlot

+ (instancetype)plotFor:(BRHLatencyByTimeGraph *)graph
{
    return [[BRHLatencyByTimeGraphMissingPlot alloc] initFor:graph];
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
    plot.identifier = @"Missing";
    plot.delegate = self;
    plot.dataSource = self;
    plot.cachePrecision = CPTPlotCachePrecisionDouble;
    plot.dataLineStyle = nil;

    // Add plot symbols
    CPTPlotSymbol *plotSymbol = [CPTPlotSymbol ellipsePlotSymbol];
    plotSymbol.fill = [CPTFill fillWithColor:[CPTColor redColor]];
    plotSymbol.lineStyle = nil;
    plotSymbol.size = CGSizeMake(kPlotSymbolSize, kPlotSymbolSize);
    plot.plotSymbol = plotSymbol;
    plot.plotSymbolMarginForHitDetection = kPlotSymbolSize * 1.5;

    return plot;
}

- (NSArray *)dataSource
{
    return self.runData.missing;
    return nil;
}

- (NSRange)getUpdateRangeFrom:(BRHRunDataNotificationInfo *)info
{
    return NSMakeRange(info.missingIndex, info.missingCount);
}

@end
