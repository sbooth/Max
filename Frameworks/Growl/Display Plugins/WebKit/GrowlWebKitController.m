//
//  GrowlWebKitController.m
//  Growl
//
//  Created by Ingmar Stein on Thu Apr 14 2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlWebKitController.h"
#import "GrowlWebKitWindowController.h"
#import "GrowlWebKitPrefsController.h"
#import "GrowlDefines.h"

@implementation GrowlWebKitController

#pragma mark -
- (id) initWithStyle:(NSString *)styleName {
	if ((self = [super init])) {
		style = [styleName retain];
	}
	return self;
}

- (void) dealloc {
	[style               release];
	[preferencePane      release];
	[clickHandlerEnabled release];
	[super dealloc];
}

- (NSPreferencePane *) preferencePane {
	if (!preferencePane) {
		// load GrowlWebKitPrefsController dynamically so that GHA does not
		// have to link against it and all of its dependencies
		Class prefsController = NSClassFromString(@"GrowlWebKitPrefsController");
		preferencePane = [[prefsController alloc] initWithStyle:style];
	}
	return preferencePane;
}

- (void) displayNotificationWithInfo:(NSDictionary *) noteDict {
	clickHandlerEnabled = [[noteDict objectForKey:@"ClickHandlerEnabled"] retain];
	// load GrowlWebKitWindowController dynamically so that the prefpane does not
	// have to link against it and all of its dependencies
	Class webKitWindowController = NSClassFromString(@"GrowlWebKitWindowController");
	GrowlWebKitWindowController *controller = [[webKitWindowController alloc]
		initWithTitle: [noteDict objectForKey:GROWL_NOTIFICATION_TITLE]
				 text: [noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
				 icon: [noteDict objectForKey:GROWL_NOTIFICATION_ICON]
			 priority:[[noteDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]
			   sticky:[[noteDict objectForKey:GROWL_NOTIFICATION_STICKY]  boolValue]
		   identifier: [noteDict objectForKey:GROWL_NOTIFICATION_IDENTIFIER]
				style:style];
	[controller setTarget:self];
	[controller setAction:@selector(_notificationClicked:)];
	[controller setAppName:[noteDict objectForKey:GROWL_APP_NAME]];
	[controller setAppPid:[noteDict objectForKey:GROWL_APP_PID]];
	[controller setClickContext:[noteDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]];
	[controller setScreenshotModeEnabled:[[noteDict objectForKey:GROWL_SCREENSHOT_MODE] boolValue]];
	[controller release];
}

- (void) _notificationClicked:(GrowlWebKitWindowController *)windowController {
	id clickContext;

	if ((clickContext = [windowController clickContext])) {
		NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
			clickHandlerEnabled,       @"ClickHandlerEnabled",
			clickContext,              GROWL_KEY_CLICKED_CONTEXT,
			[windowController appPid], GROWL_APP_PID,
			nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION_CLICKED
														   object:[windowController appName]
														  userInfo:userInfo];
		[userInfo release];

		//Avoid duplicate click messages by immediately clearing the clickContext
		[windowController setClickContext:nil];
	}
}

@end
