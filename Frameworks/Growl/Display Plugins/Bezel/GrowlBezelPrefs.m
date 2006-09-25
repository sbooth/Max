//
//  GrowlBezelPrefs.m
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 14/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "GrowlBezelPrefs.h"
#import "GrowlDefinesInternal.h"

@implementation GrowlBezelPrefs

- (NSString *) mainNibName {
	return @"GrowlBezelPrefs";
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
	READ_GROWL_PREF_VALUE(key, BezelPrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:[NSData class]]) {
		color = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		color = defaultColor;
	}
	[data release];

	return color;
}

#pragma mark -

- (float) opacity {
	float value = BEZEL_OPACITY_DEFAULT;
	READ_GROWL_PREF_FLOAT(BEZEL_OPACITY_PREF, BezelPrefDomain, &value);
	return value;
}

- (void) setOpacity:(float)value {
	WRITE_GROWL_PREF_FLOAT(BEZEL_OPACITY_PREF, value, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (float) duration {
	float value = 3.0f;
	READ_GROWL_PREF_FLOAT(BEZEL_DURATION_PREF, BezelPrefDomain, &value);
	return value;
}

- (void) setDuration:(float)value {
	WRITE_GROWL_PREF_FLOAT(BEZEL_DURATION_PREF, value, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (int) size {
	int value = 0;
	READ_GROWL_PREF_INT(BEZEL_SIZE_PREF, BezelPrefDomain, &value);
	return value;
}

- (void) setSize:(int)value {
	WRITE_GROWL_PREF_INT(BEZEL_SIZE_PREF, value, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

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
	READ_GROWL_PREF_INT(BEZEL_SCREEN_PREF, BezelPrefDomain, &value);
	return value;
}

- (void) setScreen:(int)value {
	WRITE_GROWL_PREF_INT(BEZEL_SCREEN_PREF, value, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (int) style {
	int value = 0;
	READ_GROWL_PREF_INT(BEZEL_STYLE_PREF, BezelPrefDomain, &value);
	return value;
}

- (void) setStyle:(int)value {
	WRITE_GROWL_PREF_INT(BEZEL_STYLE_PREF, value, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (int) position {
	int value = BEZEL_POSITION_DEFAULT;
	READ_GROWL_PREF_INT(BEZEL_POSITION_PREF, BezelPrefDomain, &value);
	return value;
}

- (void) setPosition:(int)value {
	WRITE_GROWL_PREF_INT(BEZEL_POSITION_PREF, value, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (BOOL) shrink {
	BOOL shrink = YES;
	READ_GROWL_PREF_BOOL(BEZEL_SHRINK_PREF, BezelPrefDomain, &shrink);
	return shrink;
}

- (void) setShrink:(BOOL)flag {
	WRITE_GROWL_PREF_BOOL(BEZEL_SHRINK_PREF, flag, BezelPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (NSColor *) textColorVeryLow {
	return [GrowlBezelPrefs loadColor:GrowlBezelVeryLowTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorVeryLow:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelVeryLowTextColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorModerate {
	return [GrowlBezelPrefs loadColor:GrowlBezelModerateTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorModerate:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelModerateTextColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorNormal {
	return [GrowlBezelPrefs loadColor:GrowlBezelNormalTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorNormal:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelNormalTextColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorHigh {
	return [GrowlBezelPrefs loadColor:GrowlBezelHighTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorHigh:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelHighTextColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorEmergency {
	return [GrowlBezelPrefs loadColor:GrowlBezelEmergencyTextColor
						 defaultColor:[NSColor whiteColor]];
}

- (void) setTextColorEmergency:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelEmergencyTextColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

#pragma mark -

- (NSColor *) backgroundColorVeryLow {
	return [GrowlBezelPrefs loadColor:GrowlBezelVeryLowBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorVeryLow:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelVeryLowBackgroundColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorModerate {
	return [GrowlBezelPrefs loadColor:GrowlBezelModerateBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorModerate:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelModerateBackgroundColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorNormal {
	return [GrowlBezelPrefs loadColor:GrowlBezelNormalBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorNormal:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelNormalBackgroundColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorHigh {
	return [GrowlBezelPrefs loadColor:GrowlBezelHighBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorHigh:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelHighBackgroundColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) backgroundColorEmergency {
	return [GrowlBezelPrefs loadColor:GrowlBezelEmergencyBackgroundColor
						 defaultColor:[NSColor blackColor]];
}

- (void) setBackgroundColorEmergency:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBezelEmergencyBackgroundColor, theData, BezelPrefDomain);
    UPDATE_GROWL_PREFS();
}
@end
