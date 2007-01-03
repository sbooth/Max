//
//  GrowlMusicVideoDisplay.h
//  Growl Display Plugins
//
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//
#import "GrowlMusicVideoDisplay.h"
#import "GrowlMusicVideoWindowController.h"
#import "GrowlMusicVideoPrefs.h"
#import <GrowlDefinesInternal.h>

@implementation GrowlMusicVideoDisplay

- (id) init {
	if ((self = [super init])) {
		notificationQueue = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[notificationQueue   release];
	[preferencePane      release];
	[clickHandlerEnabled release];
	[super dealloc];
}

- (NSPreferencePane *) preferencePane {
	if (!preferencePane)
		preferencePane = [[GrowlMusicVideoPrefs alloc] initWithBundle:[NSBundle bundleForClass:[GrowlMusicVideoPrefs class]]];
	return preferencePane;
}

#pragma mark -

- (void) displayNotificationWithInfo:(NSDictionary *) noteDict {
	clickHandlerEnabled = [[noteDict objectForKey:@"ClickHandlerEnabled"] retain];

	NSString *identifier = [noteDict objectForKey:GROWL_NOTIFICATION_IDENTIFIER];
	unsigned count = [notificationQueue count];

	if (count > 0U) {
		GrowlMusicVideoWindowController *aNotification;
		NSEnumerator *enumerator = [notificationQueue objectEnumerator];
		unsigned theIndex = 0U;

		while ((aNotification = [enumerator nextObject])) {
			if ([[aNotification identifier] isEqualToString:identifier]) {
				if (![aNotification isFadingOut]) {
					// coalescing
					[aNotification setPriority:[[noteDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]];
					[aNotification setTitle:[noteDict objectForKey:GROWL_NOTIFICATION_TITLE]];
					[aNotification setText:[noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]];
					[aNotification setIcon:[noteDict objectForKey:GROWL_NOTIFICATION_ICON]];
					[aNotification setAppName:[noteDict objectForKey:GROWL_APP_NAME]];
					[aNotification setAppPid:[noteDict objectForKey:GROWL_APP_PID]];
					[aNotification setClickContext:[noteDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]];
					[aNotification setScreenshotModeEnabled:[[noteDict objectForKey:GROWL_SCREENSHOT_MODE] boolValue]];
					if (theIndex == 0U)
						[aNotification startFadeIn];
					return;
				}
				break;
			}
			++theIndex;
		}
	}

	GrowlMusicVideoWindowController *nuMusicVideo = [[GrowlMusicVideoWindowController alloc]
		initWithTitle:[noteDict objectForKey:GROWL_NOTIFICATION_TITLE]
				 text:[noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION]
				 icon:[noteDict objectForKey:GROWL_NOTIFICATION_ICON]
			 priority:[[noteDict objectForKey:GROWL_NOTIFICATION_PRIORITY] intValue]
		   identifier:identifier];
	[nuMusicVideo setDelegate:self];
	[nuMusicVideo setTarget:self];
	[nuMusicVideo setAction:@selector(_musicVideoClicked:)];
	[nuMusicVideo setAppName:[noteDict objectForKey:GROWL_APP_NAME]];
	[nuMusicVideo setAppPid:[noteDict objectForKey:GROWL_APP_PID]];
	[nuMusicVideo setClickContext:[noteDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT]];
	[nuMusicVideo setScreenshotModeEnabled:[[noteDict objectForKey:GROWL_SCREENSHOT_MODE] boolValue]];

	if (count > 0U) {
		GrowlMusicVideoWindowController *aNotification;
		NSEnumerator *enumerator = [notificationQueue objectEnumerator];
		unsigned theIndex = 0U;

		while ((aNotification = [enumerator nextObject])) {
			if ([aNotification priority] < [nuMusicVideo priority]) {
				[notificationQueue insertObject:nuMusicVideo atIndex:theIndex];
				if (theIndex == 0U) {
					[aNotification stopFadeOut];
					[nuMusicVideo startFadeIn];
				}
				break;
			}
			++theIndex;
		}

		if (theIndex == count)
			[notificationQueue addObject:nuMusicVideo];
	} else {
		[notificationQueue addObject:nuMusicVideo];
		[nuMusicVideo startFadeIn];
	}
	[nuMusicVideo release];
}

- (void) willFadeOut:(FadingWindowController *)sender {
#pragma unused(sender)
	if ([notificationQueue count] > 1U)
		[[notificationQueue objectAtIndex:1U] startFadeIn];
}

- (void) didFadeOut:(FadingWindowController *)sender {
#pragma unused(sender)
	[notificationQueue removeObjectAtIndex:0U];
	if ([notificationQueue count] > 0U) {
		FadingWindowController *controller = [notificationQueue objectAtIndex:0U];
		if (![controller isFadingIn]) {
			[controller startFadeIn];
		}
	}
}

- (void) _musicVideoClicked:(GrowlMusicVideoWindowController *)controller {
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
