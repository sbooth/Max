//
//  NSMutableStringAdditions.m
//  Growl
//
//  Created by Ingmar Stein on 19.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "NSMutableStringAdditions.h"

@implementation NSMutableString (GrowlAdditions)
/*!
 * @brief Escape a string for passing to JavaScript scripts.
 */
- (NSMutableString *) escapeForJavaScript {
	NSRange range = NSMakeRange(0, [self length]);
	unsigned delta;
	//We need to escape a few things to get our string to the javascript without trouble
	delta = [self replaceOccurrencesOfString:@"\\" withString:@"\\\\"
									 options:NSLiteralSearch range:range];
	range.length += delta;

	delta = [self replaceOccurrencesOfString:@"\"" withString:@"\\\""
									 options:NSLiteralSearch range:range];
	range.length += delta;

	delta = [self replaceOccurrencesOfString:@"\n" withString:@""
									 options:NSLiteralSearch range:range];
	range.length -= delta;

	delta = [self replaceOccurrencesOfString:@"\r" withString:@"<br />"
									 options:NSLiteralSearch range:range];
	range.length += delta * 5;

	return self;
}

/*!
 * @brief Escape a string for HTML.
 */
- (NSMutableString *) escapeForHTML {
	BOOL freeWhenDone;
	unsigned j = 0U;
	unsigned count = CFStringGetLength((CFStringRef)self);
	UniChar c;
	UniChar *inbuffer = (UniChar *)CFStringGetCharactersPtr((CFStringRef)self);
	// worst case is a string consisting only of newlines or apostrophes
	UniChar *outbuffer = (UniChar *)malloc(6 * count * sizeof(UniChar));

	if (inbuffer) {
		freeWhenDone = NO;
	} else {
		CFRange range;
		range.location = 0U;
		range.length = count;

		freeWhenDone = YES;
		inbuffer = (UniChar *)malloc(count * sizeof(UniChar));
		CFStringGetCharacters((CFStringRef)self, range, inbuffer);
	}

	for (unsigned i=0U; i < count; ++i) {
		switch ((c=inbuffer[i])) {
			default:
				outbuffer[j++] = c;
				break;
			case '&':
				outbuffer[j++] = '&';
				outbuffer[j++] = 'a';
				outbuffer[j++] = 'm';
				outbuffer[j++] = 'p';
				outbuffer[j++] = ';';
				break;
			case '"':
				outbuffer[j++] = '&';
				outbuffer[j++] = 'q';
				outbuffer[j++] = 'u';
				outbuffer[j++] = 'o';
				outbuffer[j++] = 't';
				outbuffer[j++] = ';';
				break;
			case '<':
				outbuffer[j++] = '&';
				outbuffer[j++] = 'l';
				outbuffer[j++] = 't';
				outbuffer[j++] = ';';
				break;
			case '>':
				outbuffer[j++] = '&';
				outbuffer[j++] = 'g';
				outbuffer[j++] = 't';
				outbuffer[j++] = ';';
				break;
			case '\'':
				outbuffer[j++] = '&';
				outbuffer[j++] = 'a';
				outbuffer[j++] = 'p';
				outbuffer[j++] = 'o';
				outbuffer[j++] = 's';
				outbuffer[j++] = ';';
				break;
			case '\n':
			case '\r':
				outbuffer[j++] = '<';
				outbuffer[j++] = 'b';
				outbuffer[j++] = 'r';
				outbuffer[j++] = ' ';
				outbuffer[j++] = '/';
				outbuffer[j++] = '>';
				break;
		}
	}
	CFStringRef result = CFStringCreateWithCharactersNoCopy(kCFAllocatorDefault, outbuffer, j, kCFAllocatorNull);
	CFStringReplaceAll((CFMutableStringRef)self, result);
	CFRelease(result);
	free(outbuffer);
	if (freeWhenDone)
		free(inbuffer);

	return self;
}
@end
