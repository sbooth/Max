//
//  ARTchiveStringAdditions.m
//  ARTchive
//
//  Created by Kevin Ballard on 10/5/04.
//  Copyright 2004 Kevin Ballard. All rights reserved.
//

#import "ARTchiveStringAdditions.h"

@implementation NSString (ARTchiveStringAdditions)

- (NSString *)stringByMakingPathSafe {
	size_t numChars = [self length];
	unichar *chars = malloc(numChars * sizeof(unichar));
	if(!chars) {
		NSLog(@"In -[NSString(ARTchiveStringAdditions) stringByMakingPathSafe:]: Could not allocate %lu bytes of memory in which to examine the full album name", (unsigned long)(numChars * sizeof(unichar)));
		return nil;
	}
	[self getCharacters:chars];

	for(unsigned long i = 0U; i < numChars; ++i) {
		switch(chars[i]) {
			case ':':
			case '/':
				chars[i] = '_';
		}
	}

	NSString *result = [NSString stringWithCharacters:chars length:numChars];
	free(chars);
	return result;
}

@end
