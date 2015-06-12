// BRHLatencyByTimeGraphAveragePlot.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimeGraph.h"
#import "BRHLatencyByTimeGraphPlot.h"
#import "BRHLatencySample.h"
#import "BRHRunData.h"

@implementation BRHLatencyByTimeGraphPlot

- (instancetype)initFor:(BRHLatencyByTimeGraph *)graph
{
    if (self = [super init]) {
        _graph = graph;
        _runData = graph.runData;
        _plot = nil;
    }

    return self;
}

- (CPTScatterPlot *)makePlot
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (CPTScatterPlot *)plot
{
    if (! _plot) {
        _plot = [self makePlot];
    }

    return _plot;
}

- (void)setRunData:(BRHRunData *)runData
{
    _runData = runData;
    [_plot setDataNeedsReloading];
}

- (NSArray *)dataSource
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSRange)getUpdateRangeFrom:(BRHRunDataNotificationInfo *)info
{
    [self doesNotRecognizeSelector:_cmd];
    return NSMakeRange(0, 0);
}

- (void)update:(BRHRunDataNotificationInfo *)info
{
    NSRange range = [self getUpdateRangeFrom:info];
    if (range.length) {
        [_plot insertDataAtIndex:range.location numberOfRecords:range.length];
    }
}

#pragma mark Data Source Methods

- (NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return self.dataSource.count;
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    BRHLatencySample *sample = self.dataSource[index];
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            return [NSNumber numberWithDouble:[_graph xValueFor:sample]];
            break;

        case CPTScatterPlotFieldY:
            return [sample valueForKey:self.sampleValueKey];
            break;
            
        default:
            break;
    }

    return nil;
}

#pragma mark - Plot Delegate Methods

- (void)legend:(CPTLegend *)legend legendEntryForPlot:(CPTPlot *)plot wasSelectedAtIndex:(NSUInteger)idx
{
    plot.hidden = ! plot.hidden;
}

@end
