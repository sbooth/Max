//
//  GrowlSmokeDisplay.m
//  Display Plugins
//
//  Created by Matthew Walton on 09/09/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlSmokeDisplay.h"
#import "GrowlSmokeWindowController.h"
#import "GrowlSmokePrefsController.h"
#import "GrowlSmokeDefines.h"
#import "GrowlDefinesInternal.h"

static unsigned smokeDepth = 0U;

@implementation GrowlSmokeDisplay

- (id) init {
	if ((self = [super init])) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_smokeGone:)
													 name:@"SmokeGone"
												   object:nil];
	}
	return self;
}

- (void) dealloc {
	[preferencePane      release];
	[clickHandlerEnabled release];
	[super dealloc];
}

- (NSPreferencePane *) preferencePane {
	if (!preferencePane) {
		preferencePane = [[GrowlSmokePrefsController alloc] initWithBundle:[NSBundle bundleForClass:[GrowlSmokePrefsController class]]];
	}
	return preferencePane;
}

- (void) displayNotificationWithInfo:(NSDictionary *)noteDict {
	clickHandlerEnabled = [[noteDict objectForKey:@"ClickHandlerEnabled"] retain];
	GrowlSmokeWindowController *controller = [[GrowlSmokeWindowController alloc]
		initWithTitle:[noteDict objectForKey:GROWL_NOTIFICATION_TITLE]
				 text:[noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
				 icon:[noteDict objectForKey:GROWL_NOTIFICATION_ICON]
			 priority:[[noteDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]
			   sticky:[[noteDict objectForKey:GROWL_NOTIFICATION_STICKY] boolValue]
				depth:smokeDepth
		   identifier:[noteDict objectForKey:GROWL_NOTIFICATION_IDENTIFIER]];

	[controller setTarget:self];
	[controller setAction:@selector(_smokeClicked:)];
	[controller setAppName:[noteDict objectForKey:GROWL_APP_NAME]];
	[controller setAppPid:[noteDict objectForKey:GROWL_APP_PID]];
	[controller setClickContext:[noteDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]];
	[controller setScreenshotModeEnabled:[[noteDict objectForKey:GROWL_SCREENSHOT_MODE] boolValue]];

	// update the depth for the next notification with the depth given by this new one
	// which will take into account the new notification's height
	smokeDepth = [controller depth] + GrowlSmokePadding;
	[controller startFadeIn];
	[controller release];
}

- (void) _smokeGone:(NSNotification *)note {
	unsigned notifiedDepth = [[[note userInfo] objectForKey:@"Depth"] intValue];
	//NSLog(@"Received notification of departure with depth %u, my depth is %u\n", notifiedDepth, smokeDepth);
	if (smokeDepth > notifiedDepth) {
		smokeDepth = notifiedDepth;
	}
	//NSLog(@"My depth is now %u\n", smokeDepth);
}

- (void) _smokeClicked:(GrowlSmokeWindowController *)controller {
	id clickContext;

	if ((clickContext = [controller clickContext])) {
		NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
			clickHandlerEnabled, @"ClickHandlerEnabled",
			clickContext,        GROWL_KEY_CLICKED_CONTEXT,
			[controller appPid], GROWL_APP_PID,
			nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION_CLICKED
															object:[controller appName]
														  userInfo:userInfo];
		[userInfo release];

		//Avoid duplicate click messages by immediately clearing the clickContext
		[controller setClickContext:nil];
	}
}

@end
