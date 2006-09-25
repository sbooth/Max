//
//  GrowlSpeechPrefs.m
//  Display Plugins
//
//  Created by Ingmar Stein on 15.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlSpeechPrefs.h"
#import "GrowlSpeechDefines.h"
#import <AppKit/NSSpeechSynthesizer.h>

@implementation GrowlSpeechPrefs
- (NSString *) mainNibName {
	return @"GrowlSpeechPrefs";
}

- (void) awakeFromNib {
	NSArray *availableVoices = [NSSpeechSynthesizer availableVoices];
	NSEnumerator *voiceEnum = [availableVoices objectEnumerator];
	NSMutableArray *voiceAttributes = [[NSMutableArray alloc] initWithCapacity:[availableVoices count]];
	NSString *voiceIdentifier;
	while ((voiceIdentifier=[voiceEnum nextObject])) {
		[voiceAttributes addObject:[NSSpeechSynthesizer attributesForVoice:voiceIdentifier]];
	}
	[self setVoices:voiceAttributes];
	[voiceAttributes release];

	NSString *voice = nil;
	READ_GROWL_PREF_VALUE(GrowlSpeechVoicePref, GrowlSpeechPrefDomain, NSString *, &voice);
	int row;
	if (voice) {
		row = [availableVoices indexOfObject:voice];
		[voice release];
	} else {
		row = [availableVoices indexOfObject:[NSSpeechSynthesizer defaultVoice]];
	}
	[voiceList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[voiceList scrollRowToVisible:row];
}

- (NSArray *) voices {
	return voices;
}

- (void) setVoices:(NSArray *)theVoices {
	[voices release];
	voices = [theVoices retain];
}

- (void) dealloc {
	[voices release];
	[super dealloc];
}

- (IBAction) voiceClicked:(id)sender {
	int row = [sender selectedRow];

	if (-1 != row) {
		NSString *voice = [[voices objectAtIndex:row] objectForKey:NSVoiceIdentifier];
		WRITE_GROWL_PREF_VALUE(GrowlSpeechVoicePref, voice, GrowlSpeechPrefDomain);
		UPDATE_GROWL_PREFS();
	}
}

@end
