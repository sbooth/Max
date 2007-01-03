/*
 *  HelperMain.m
 *  Growl
 *
 *  Created by Karl Adam on Thu Apr 22 2004.
 *  Copyright (c) 2004 The Growl Project. All rights reserved.
 *
 */

#import "GrowlController.h"

int main(void) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];

	GrowlController *theOneRingToRuleThemAll;
	theOneRingToRuleThemAll = [[GrowlController alloc] init];

	[NSApp setDelegate:theOneRingToRuleThemAll];
	[NSApp run];

	[theOneRingToRuleThemAll release];
	[NSApp release];
	[pool release];

	return EXIT_SUCCESS;
}


