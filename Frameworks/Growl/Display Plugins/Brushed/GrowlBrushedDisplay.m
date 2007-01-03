//
//  GrowlBrushedDisplay.m
//  Display Plugins
//
//  Created by Ingmar Stein on 12/01/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlBrushedDisplay.h"
#import "GrowlBrushedWindowController.h"
#import "GrowlBrushedPrefsController.h"
#import "GrowlBrushedDefines.h"
#import "GrowlDefinesInternal.h"

static unsigned brushedDepth = 0U;

@implementation GrowlBrushedDisplay

- (id) init {
	if ((self = [super init])) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(_brushedGone:)
													 name:@"BrushedGone"
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
		preferencePane = [[GrowlBrushedPrefsController alloc] initWithBundle:[NSBundle bundleForClass:[GrowlBrushedPrefsController class]]];
	}
	return preferencePane;
}

- (void) displayNotificationWithInfo:(NSDictionary *)noteDict {
	clickHandlerEnabled = [[noteDict objectForKey:@"ClickHandlerEnabled"] retain];
	GrowlBrushedWindowController *controller = [[GrowlBrushedWindowController alloc]
		initWithTitle:[noteDict objectForKey:GROWL_NOTIFICATION_TITLE]
				 text:[noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
				 icon:[noteDict objectForKey:GROWL_NOTIFICATION_ICON]
			 priority:[[noteDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]
			   sticky:[[noteDict objectForKey:GROWL_NOTIFICATION_STICKY] boolValue]
				depth:brushedDepth
		   identifier:[noteDict objectForKey:GROWL_NOTIFICATION_IDENTIFIER]];

	[controller setTarget:self];
	[controller setAction:@selector(_brushedClicked:)];
	[controller setAppName:[noteDict objectForKey:GROWL_APP_NAME]];
	[controller setAppPid:[noteDict objectForKey:GROWL_APP_PID]];
	[controller setClickContext:[noteDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]];
	[controller setScreenshotModeEnabled:[[noteDict objectForKey:GROWL_SCREENSHOT_MODE] boolValue]];

	// update the depth for the next notification with the depth given by this new one
	// which will take into account the new notification's height
	brushedDepth = [controller depth] + GrowlBrushedPadding;
	[controller startFadeIn];
	[controller release];
}

- (void) _brushedGone:(NSNotification *)note {
	unsigned notifiedDepth = [[[note userInfo] objectForKey:@"Depth"] intValue];
	//NSLog(@"Received notification of departure with depth %u, my depth is %u\n", notifiedDepth, brushedDepth);
	if (brushedDepth > notifiedDepth) {
		brushedDepth = notifiedDepth;
	}
	//NSLog(@"My depth is now %u\n", brushedDepth);
}

- (void) _brushedClicked:(GrowlBrushedWindowController *)controller {
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
