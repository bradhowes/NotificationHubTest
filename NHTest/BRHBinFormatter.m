// BRHBinFormatter.m
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHBinFormatter.h"

/*!
 @brief Private properties of BRHBinFormatter
 */
@interface BRHBinFormatter ()

/*!
 @brief The index of the last bin in the histogram
 */
@property (assign, nonatomic) NSUInteger lastBin;
/*!
 @brief The label to use for the last bin
 */
@property (copy, nonatomic) NSString *lastBinLabel;

@end

@implementation BRHBinFormatter

+ (BRHBinFormatter *)binFormatterWithLastBin:(NSUInteger)lastBin
{
    BRHBinFormatter *obj = [[BRHBinFormatter alloc] initWithLastBin:lastBin];
    return obj;
}

- (instancetype)initWithLastBin:(NSUInteger)lastBin
{
    if ((self = [super init]) != nil) {
        _lastBin = lastBin;
        _lastBinLabel = [NSString stringWithFormat:@"%ld+", (long)lastBin];
    }

    return self;
}

/*!
 @brief  Override of NSNumber method. Generates the label for a bin.
 
 @param obj NSNumber object holding the index of the bin to label
 
 @return NSString label for the bin
 */
- (NSString *)stringForObjectValue:(id)obj
{
    NSInteger value = [obj integerValue];
    if (value == 0) {
        return @"<1";
    }
    else if (value == self.lastBin) {
        return self.lastBinLabel;
    }
    else {
        return [NSString stringWithFormat:@"%ld", (long)value];
    }
}

@end
