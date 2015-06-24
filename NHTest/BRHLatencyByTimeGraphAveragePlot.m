// BRHLatencyByTimeGraphAveragePlot.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimeGraphAveragePlot.h"
#import "BRHRecordingInfo.h"
#import "BRHRunData.h"

@implementation BRHLatencyByTimeGraphAveragePlot

+ (instancetype)plotFor:(BRHLatencyByTimeGraph *)graph
{
    return [[BRHLatencyByTimeGraphAveragePlot alloc] initFor:graph];
}

- (instancetype)initFor:(BRHLatencyByTimeGraph *)graph
{
    if (self = [super initFor:graph]) {
        self.sampleValueKey = @"average";
    }

    return self;
}

- (CPTScatterPlot *)makePlot
{
    CPTScatterPlot *plot = [[CPTScatterPlot alloc] init];
    plot.identifier = @"Average";
    plot.dataSource = self;
    plot.cachePrecision = CPTPlotCachePrecisionDouble;
    plot.dataLineStyle = nil;

    CPTMutableLineStyle *lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineJoin = kCGLineJoinRound;
    lineStyle.lineCap = kCGLineCapRound;
    lineStyle.lineWidth = 3.0f;
    lineStyle.lineColor = [[CPTColor yellowColor] colorWithAlphaComponent:1.0];
    plot.dataLineStyle = lineStyle;

    return plot;
}

- (NSArray *)dataSource
{
    return self.recordingInfo.runData.samples;
    return nil;
}

- (NSRange)getUpdateRangeFrom:(BRHRunDataNotificationInfo *)info
{
    return NSMakeRange(info.sampleIndex, info.sampleCount);
}

@end
