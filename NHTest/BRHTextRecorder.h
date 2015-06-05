// BRHTextRecorder.h
// NHTest
//
// Copyright (C) 2015 Brad Howes. All rights reserved.

#import <Foundation/Foundation.h>

/*!
 * @brief Simple text logger that writes to a file
 */
@interface BRHTextRecorder : NSObject

/*!
 * @brief Location of the log file being written to.
 * When being set, this must be a directory or folder to hold the log file.
 */
@property (strong, nonatomic) NSURL *logPath;

/*!
 * @brief Attached UITetView view which shows the contents of the log file.
 */
@property (strong, nonatomic) UITextView *textView;

- (instancetype)initWithFileName:(NSString *)fileName;

- (NSString *)timestamp;

- (NSString *)addLine:(NSString *)line;

/*!
 *    @brief  Force a save of the log file.
 */
- (void)save;

/*!
 *    @brief  Reset the log to be the empty string and empty file.
 */
- (void)clear;

@end
