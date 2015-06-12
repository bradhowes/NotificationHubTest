// BRHLatencyByTimeGraphAveragePlot.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHLatencyByTimeGraphPlot.h"

@interface BRHLatencyByTimeGraphAveragePlot : BRHLatencyByTimeGraphPlot

+ (instancetype)plotFor:(BRHLatencyByTimeGraph *)graph;

- (instancetype)initFor:(BRHLatencyByTimeGraph *)graph;

@end
