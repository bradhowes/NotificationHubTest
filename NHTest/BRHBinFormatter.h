// BRHBinFormatter.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

/*!
 * @brief Number formatter used by the histogram plots to render the bin names.
 */
@interface BRHBinFormatter : NSNumberFormatter

/*!
 * @brief Class method to creat a new BRHBinFormatter object
 *
 * @param lastBin the value of the last bin in the histogram (basically histogram size - 1)
 *
 * @return new BRHBinFormatter instance
 */
+ (BRHBinFormatter *)binFormatterWithLastBin:(NSUInteger)lastBin;

/*!
 * @brief Initializer for BRHBinFormatter objects
 *
 * @param lastBin the value of the last bin in the histogram (basically histogram size - 1)
 *
 * @return initialized BRHBinFormatter instance
 */
- (instancetype)initWithLastBin:(NSUInteger)lastBin;

@end

