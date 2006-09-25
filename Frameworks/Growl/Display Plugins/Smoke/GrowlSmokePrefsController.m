//
//  GrowlSmokePrefsController.m
//  Display Plugins
//
//  Created by Matthew Walton on 11/09/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlSmokePrefsController.h"
#import "GrowlSmokeDefines.h"
#import "GrowlDefinesInternal.h"

@implementation GrowlSmokePrefsController

- (NSString *) mainNibName {
	return @"SmokePrefs";
}

+ (void) loadColorWell:(NSColorWell *)colorWell fromKey:(NSString *)key defaultColor:(NSColor *)defaultColor {
	NSData *data = nil;
	NSColor *color;
	READ_GROWL_PREF_VALUE(key, GrowlSmokePrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:[NSData class]]) {
		color = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		color = defaultColor;
	}
	[colorWell setColor:color];
	[data release];
}

- (void) mainViewDidLoad {
	[slider_opacity setAltIncrementValue:0.05];

	// priority colour settings
	NSColor *defaultColor = [NSColor colorWithCalibratedWhite:0.1f alpha:1.0f];

	[GrowlSmokePrefsController loadColorWell:color_veryLow fromKey:GrowlSmokeVeryLowColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:color_moderate fromKey:GrowlSmokeModerateColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:color_normal fromKey:GrowlSmokeNormalColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:color_high fromKey:GrowlSmokeHighColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:color_emergency fromKey:GrowlSmokeEmergencyColor defaultColor:defaultColor];

	defaultColor = [NSColor whiteColor];

	[GrowlSmokePrefsController loadColorWell:text_veryLow fromKey:GrowlSmokeVeryLowTextColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:text_moderate fromKey:GrowlSmokeModerateTextColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:text_normal fromKey:GrowlSmokeNormalTextColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:text_high fromKey:GrowlSmokeHighTextColor defaultColor:defaultColor];
	[GrowlSmokePrefsController loadColorWell:text_emergency fromKey:GrowlSmokeEmergencyTextColor defaultColor:defaultColor];
}

- (float) opacity {
	float value = GrowlSmokeAlphaPrefDefault;
	READ_GROWL_PREF_FLOAT(GrowlSmokeAlphaPref, GrowlSmokePrefDomain, &value);
	return value;
}

- (void) setOpacity:(float)value {
	WRITE_GROWL_PREF_FLOAT(GrowlSmokeAlphaPref, value, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

- (float) duration {
	float value = GrowlSmokeDurationPrefDefault;
	READ_GROWL_PREF_FLOAT(GrowlSmokeDurationPref, GrowlSmokePrefDomain, &value);
	return value;
}

- (void) setDuration:(float)value {
	WRITE_GROWL_PREF_FLOAT(GrowlSmokeDurationPref, value, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

- (IBAction) colorChanged:(id)sender {
	NSString *key;
	switch ([sender tag]) {
		case -2:
			key = GrowlSmokeVeryLowColor;
			break;
		case -1:
			key = GrowlSmokeModerateColor;
			break;
		case 1:
			key = GrowlSmokeHighColor;
			break;
		case 2:
			key = GrowlSmokeEmergencyColor;
			break;
		case 0:
		default:
			key = GrowlSmokeNormalColor;
			break;
	}

	NSData *theData = [NSArchiver archivedDataWithRootObject:[sender color]];
	WRITE_GROWL_PREF_VALUE(key, theData, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

- (IBAction) textColorChanged:(id)sender {
	NSString *key;
	switch ([sender tag]) {
		case -2:
			key = GrowlSmokeVeryLowTextColor;
			break;
		case -1:
			key = GrowlSmokeModerateTextColor;
			break;
		case 1:
			key = GrowlSmokeHighTextColor;
			break;
		case 2:
			key = GrowlSmokeEmergencyTextColor;
			break;
		case 0:
		default:
			key = GrowlSmokeNormalTextColor;
			break;
	}

	NSData *theData = [NSArchiver archivedDataWithRootObject:[sender color]];
	WRITE_GROWL_PREF_VALUE(key, theData, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

- (BOOL) isFloatingIcon {
	BOOL value = GrowlSmokeFloatIconPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlSmokeFloatIconPref, GrowlSmokePrefDomain, &value);
	return value;
}

- (void) setFloatingIcon:(BOOL)value {
	WRITE_GROWL_PREF_BOOL(GrowlSmokeFloatIconPref, value, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

- (BOOL) isLimit {
	BOOL value = GrowlSmokeLimitPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlSmokeLimitPref, GrowlSmokePrefDomain, &value);
	return value;
}

- (void) setLimit:(BOOL)value {
	WRITE_GROWL_PREF_BOOL(GrowlSmokeLimitPref, value, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

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
	READ_GROWL_PREF_INT(GrowlSmokeScreenPref, GrowlSmokePrefDomain, &value);
	return value;
}

- (void) setScreen:(int)value {
	WRITE_GROWL_PREF_INT(GrowlSmokeScreenPref, value, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

- (int) size {
	int value = 0;
	READ_GROWL_PREF_INT(GrowlSmokeSizePref, GrowlSmokePrefDomain, &value);
	return value;
}

- (void) setSize:(int)value {
	WRITE_GROWL_PREF_INT(GrowlSmokeSizePref, value, GrowlSmokePrefDomain);
	UPDATE_GROWL_PREFS();
}

@end
