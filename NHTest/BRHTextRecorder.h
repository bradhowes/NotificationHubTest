// BRHTextRecorder.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

/*!
 @brief Simple text logger that writes lines to a file.
 
 The contents of the logger is periodically written to the disk in a simplistic attempt to limit disk writes.
 */
@interface BRHTextRecorder : NSObject

/*!
 @brief Location of the log file being written to.
 
 When being set, this must be a directory or folder to hold the log file.
 */
@property (strong, nonatomic) NSURL *logPath;

/*!
 @brief Attached UITetView view which shows the contents of the log file.
 */
@property (strong, nonatomic) UITextView *textView;

/*!
 @brief Number of seconds to wait before writing log to disk.
 */
@property (assign, nonatomic) NSTimeInterval saveInterval;

/*!
 @brief Initialize new BRHTextRecorder instance
 
 @param fileName the existing file read for the contents of the recorder
 
 @return initialized instance
 */
- (instancetype)initWithFileName:(NSString *)fileName;

/*!
 @brief Obtain a timestamp with the format HH:mm:ss.SSSSSS.

 @return NSString representation of the current time
 */
- (NSString *)timestamp;

/*!
 @brief Add a line to the recorder.
 
 @note the line should terminate with a end-of-line character (\\n)
 
 @param line the text to add
 
 @return given line value
 */
- (NSString *)addLine:(NSString *)line;

/*!
 @brief Force a save of the log file.
 */
- (void)save;

/*!
 @brief  Reset the log to be the empty string and empty file.
 */
- (void)clear;

@end
