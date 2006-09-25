//
//  GrowlMusicVideoPrefs.m
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 14/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "GrowlMusicVideoPrefs.h"
#import <GrowlDefinesInternal.h>

@implementation GrowlMusicVideoPrefs

- (NSString *) mainNibName {
	return @"GrowlMusicVideoPrefs";
}

- (void) mainViewDidLoad {
	[slider_opacity setAltIncrementValue:5.0];
}

- (void) didSelect {
	SYNCHRONIZE_GROWL_PREFS();
}

#pragma mark -

+ (NSColor *) loadColor:(NSString *)key defaultColor:(NSColor *)defaultColor {
	NSData *data = nil;
	NSColor *color;
	READ_GROWL_PREF_VALUE(key, MusicVideoPrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:[NSData class]]) {
		color = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		color = defaultColor;
	}
	[data release];

	return color;
}

#pragma mark Accessors

- (float) duration {
	float value = MUSICVIDEO_DEFAULT_DURATION;
	READ_GROWL_PREF_FLOAT(MUSICVIDEO_DURATION_PREF, MusicVideoPrefDomain, &value);
	return value;
}
- (void) setDuration:(float)value {
	WRITE_GROWL_PREF_FLOAT(MUSICVIDEO_DURATION_PREF, value, MusicVideoPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (unsigned) effect {
	int effect = 0;
	READ_GROWL_PREF_INT(MUSICVIDEO_EFFECT_PREF, MusicVideoPrefDomain, &effect);
	switch (effect) {
		default:
			effect = MUSICVIDEO_EFFECT_SLIDE;

		case MUSICVIDEO_EFFECT_SLIDE:
		case MUSICVIDEO_EFFECT_WIPE:
			;
	}
	return (unsigned)effect;
}
- (void) setEffect:(unsigned)newEffect {
	switch (newEffect) {
		default:
			NSLog(@"(Music Video) Invalid effect number %u (slide is %u; wipe is %u)", newEffect, MUSICVIDEO_EFFECT_SLIDE, MUSICVIDEO_EFFECT_WIPE);
			break;

		case MUSICVIDEO_EFFECT_SLIDE:
		case MUSICVIDEO_EFFECT_WIPE:
			WRITE_GROWL_PREF_INT(MUSICVIDEO_EFFECT_PREF, newEffect, MusicVideoPrefDomain);
			UPDATE_GROWL_PREFS();
	}
}

- (float) opacity {
	float value = MUSICVIDEO_DEFAULT_OPACITY;
	READ_GROWL_PREF_FLOAT(MUSICVIDEO_OPACITY_PREF, MusicVideoPrefDomain, &value);
	return value;
}
- (void) setOpacity:(float)value {
	WRITE_GROWL_PREF_FLOAT(MUSICVIDEO_OPACITY_PREF, value, MusicVideoPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (int) size {
	int value = 0;
	READ_GROWL_PREF_INT(MUSICVIDEO_SIZE_PREF, MusicVideoPrefDomain, &value);
	return value;
}
- (void) setSize:(int)value {
	WRITE_GROWL_PREF_INT(MUSICVIDEO_SIZE_PREF, value, MusicVideoPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark Combo box support

- (int) numberOfItemsInComboBox:(NSComboBox *)aComboBox {
#pragma unused(aComboBox)
	return [[NSScreen screens] count];
}

- (id) comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)idx {
#pragma unused(aComboBox)
	return [NSNumber numberWithInt:idx];
}

- (int) screen {
	int value = 0;
	READ_GROWL_PREF_INT(MUSICVIDEO_SCREEN_PREF, MusicVideoPrefDomain, &value);
	return value;
}
- (void) setScreen:(int)value {
	WRITE_GROWL_PREF_INT(MUSICVIDEO_SCREEN_PREF, value, MusicVideoPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorVeryLow {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoVeryLowTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorVeryLow:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoVeryLowTextColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorModerate {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoModerateTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorModerate:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoModerateTextColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorNormal {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoNormalTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorNormal:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoNormalTextColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorHigh {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoHighTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorHigh:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoHighTextColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorEmergency {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoEmergencyTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorEmergency:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoEmergencyTextColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorVeryLow {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoVeryLowBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorVeryLow:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoVeryLowBackgroundColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorModerate {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoModerateBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorModerate:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoModerateBackgroundColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorNormal {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoNormalBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorNormal:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoNormalBackgroundColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorHigh {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoHighBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorHigh:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoHighBackgroundColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorEmergency {
	return [GrowlMusicVideoPrefs loadColor:GrowlMusicVideoEmergencyBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorEmergency:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlMusicVideoEmergencyBackgroundColor, theData, MusicVideoPrefDomain);
    UPDATE_GROWL_PREFS();
}
@end
