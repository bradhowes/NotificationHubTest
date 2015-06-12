// BRHLogger.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import "BRHTextRecorder.h"

/*!
 @brief Simple line logger that writes to a file
 */
@interface BRHLogger : BRHTextRecorder

/*!
 @brief Obtain the singleton logger
 
 @return BRHLogger instance
 */
+ (instancetype) sharedInstance;

/*!
 @brief Generate a log line using the given format string and any additional values given after it

 @param format how to format the given values for the log line

 @return the formatted line that was added to the log file
 */
+ (NSString *) add:(NSString *)format, ...;

/*!
 @brief Clear the log and attached text view
 */
+ (void)clear;

@end
