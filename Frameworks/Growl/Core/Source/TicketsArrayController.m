//
//  TicketsArrayController.m
//  Growl
//
//  Created by Ingmar Stein on 12.04.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//
//  This file is under the BSD License, refer to License.txt for details

#import "TicketsArrayController.h"
#import "GrowlApplicationTicket.h"

@implementation TicketsArrayController

- (void) dealloc {
	[searchString release];
	[super dealloc];
}

#pragma mark -

- (NSArray *) arrangeObjects:(NSArray *)objects {
	NSArray *sorted = [objects sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	if (!searchString || [searchString isEqualToString:@""]) {
		return [super arrangeObjects:sorted];
	} else {
		NSMutableArray *matchedObjects = [NSMutableArray arrayWithCapacity:[sorted count]];
		NSEnumerator *ticketEnum = [sorted objectEnumerator];
		GrowlApplicationTicket *ticket;
		while ((ticket = [ticketEnum nextObject])) {
			if ([[ticket applicationName] rangeOfString:searchString options:NSLiteralSearch|NSCaseInsensitiveSearch].location != NSNotFound) {
				[matchedObjects addObject:ticket];
			}
		}
		return [super arrangeObjects:matchedObjects];
	}
}

- (void) search:(id)sender {
	[self setSearchString:[sender stringValue]];
	[self rearrangeObjects];
}

#pragma mark -

- (NSString *) searchString {
	return searchString;
}
- (void) setSearchString:(NSString *)newSearchString {
	if (searchString != newSearchString) {
		[searchString release];
		searchString = [newSearchString copy];
	}
}

@end
