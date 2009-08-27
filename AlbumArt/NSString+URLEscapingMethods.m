/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import "NSString+URLEscapingMethods.h"

@implementation NSString(URLEscapingMethods)

- (NSString *) URLEscapedString
{
	return [self URLEscapedStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *) URLEscapedStringUsingEncoding:(NSStringEncoding)encoding
{
	CFStringEncoding CFEncoding = CFStringConvertNSStringEncodingToEncoding(encoding);
	if(kCFStringEncodingInvalidId == CFEncoding)
		return nil;
	
	// Escape all reserved characters from RFC 2396 section 2.2
	CFStringRef escapedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR(";/?:@&=+$,"), CFEncoding);
	
	NSString *result = [(NSString *)escapedString copy];
	
	CFRelease(escapedString), escapedString = NULL;
	
	return result;
}

@end
