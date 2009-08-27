/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <Cocoa/Cocoa.h>

@interface NSString(URLEscapingMethods)
- (NSString *) URLEscapedString;
- (NSString *) URLEscapedStringUsingEncoding:(NSStringEncoding)encoding;
@end
