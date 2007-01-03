//
//  GrowlSpeechDisplay.m
//  Display Plugins
//
//  Created by Ingmar Stein on 15.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlSpeechDisplay.h"
#import "GrowlSpeechPrefs.h"
#import "GrowlSpeechDefines.h"
#import "GrowlPathUtil.h"
#import <GrowlDefinesInternal.h>

@implementation GrowlSpeechDisplay
- (void) dealloc {
	[prefPane release];
	[super dealloc];
}

- (NSPreferencePane *) preferencePane {
	if (!prefPane) {
		prefPane = [[GrowlSpeechPrefs alloc] initWithBundle:[NSBundle bundleForClass:[GrowlSpeechPrefs class]]];
	}
	return prefPane;
}

- (void) displayNotificationWithInfo:(NSDictionary *)noteDict {
	NSString *voice = nil;
	READ_GROWL_PREF_VALUE(GrowlSpeechVoicePref, GrowlSpeechPrefDomain, NSString *, &voice);
	if (voice) {
		[voice autorelease];
	} else {
		voice = [NSSpeechSynthesizer defaultVoice];
	}

	NSString *desc = [noteDict objectForKey:GROWL_NOTIFICATION_DESCRIPTION];

	NSSpeechSynthesizer *syn = [[NSSpeechSynthesizer alloc] initWithVoice:voice];
	[syn startSpeakingString:desc];

	if ([[noteDict objectForKey:GROWL_SCREENSHOT_MODE] boolValue]) {
		NSString *path = [[[GrowlPathUtil screenshotsDirectory] stringByAppendingPathComponent:[GrowlPathUtil nextScreenshotName]] stringByAppendingPathExtension:@"aiff"];
		NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
		[syn startSpeakingString:desc toURL:url];
		[url release];
	}

	[syn autorelease];

	id clickContext = [noteDict objectForKey:GROWL_NOTIFICATION_CLICK_CONTEXT];
	if (clickContext) {
		NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
			[noteDict objectForKey:@"ClickHandlerEnabled"], @"ClickHandlerEnabled",
			clickContext,                                   GROWL_KEY_CLICKED_CONTEXT,
			[noteDict objectForKey:GROWL_APP_PID],          GROWL_APP_PID,
			nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION_TIMED_OUT
															object:[noteDict objectForKey:GROWL_APP_NAME]
														  userInfo:userInfo];
		[userInfo release];
	}
}
@end
