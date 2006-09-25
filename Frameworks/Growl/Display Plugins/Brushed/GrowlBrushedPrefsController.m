//
//  GrowlBrushedPrefsController.m
//  Display Plugins
//
//  Created by Ingmar Stein on 12/01/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlBrushedPrefsController.h"
#import "GrowlBrushedDefines.h"
#import "GrowlDefinesInternal.h"


@implementation GrowlBrushedPrefsController

- (NSString *) mainNibName {
	return @"BrushedPrefs";
}

+ (NSColor *) loadColor:(NSString *)key defaultColor:(NSColor *)defaultColor {
	NSData *data = nil;
	NSColor *color;
	READ_GROWL_PREF_VALUE(key, GrowlBrushedPrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:[NSData class]]) {
		color = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		color = defaultColor;
	}
	[data release];

	return color;
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

#pragma mark -

- (float) duration {
	float value = GrowlBrushedDurationPrefDefault;
	READ_GROWL_PREF_FLOAT(GrowlBrushedDurationPref, GrowlBrushedPrefDomain, &value);
	return value;
}

- (void) setDuration:(float)value {
	WRITE_GROWL_PREF_FLOAT(GrowlBrushedDurationPref, value, GrowlBrushedPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark priority color settings

- (NSColor *) textColorVeryLow {
	return [GrowlBrushedPrefsController loadColor:GrowlBrushedVeryLowTextColor
			  defaultColor:[NSColor colorWithCalibratedWhite:0.1f alpha:1.0f]];
}

- (void) setTextColorVeryLow:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBrushedVeryLowTextColor, theData, GrowlBrushedPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorModerate {
	return [GrowlBrushedPrefsController loadColor:GrowlBrushedModerateTextColor
									 defaultColor:[NSColor colorWithCalibratedWhite:0.1f alpha:1.0f]];
}

- (void) setTextColorModerate:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBrushedModerateTextColor, theData, GrowlBrushedPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorNormal {
	return [GrowlBrushedPrefsController loadColor:GrowlBrushedNormalTextColor
									 defaultColor:[NSColor colorWithCalibratedWhite:0.1f alpha:1.0f]];
}

- (void) setTextColorNormal:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBrushedNormalTextColor, theData, GrowlBrushedPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorHigh {
	return [GrowlBrushedPrefsController loadColor:GrowlBrushedHighTextColor
									 defaultColor:[NSColor colorWithCalibratedWhite:0.1f alpha:1.0f]];
}

- (void) setTextColorHigh:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBrushedHighTextColor, theData, GrowlBrushedPrefDomain);
    UPDATE_GROWL_PREFS();
}

- (NSColor *) textColorEmergency {
	return [GrowlBrushedPrefsController loadColor:GrowlBrushedEmergencyTextColor
									 defaultColor:[NSColor colorWithCalibratedWhite:0.1f alpha:1.0f]];
}

- (void) setTextColorEmergency:(NSColor *)value {
	NSData *theData = [NSArchiver archivedDataWithRootObject:value];
    WRITE_GROWL_PREF_VALUE(GrowlBrushedEmergencyTextColor, theData, GrowlBrushedPrefDomain);
    UPDATE_GROWL_PREFS();
}

#pragma mark -

- (int) screen {
	int value = 0;
	READ_GROWL_PREF_INT(GrowlBrushedScreenPref, GrowlBrushedPrefDomain, &value);
	return value;
}

- (void) setScreen:(int)value {
	WRITE_GROWL_PREF_INT(GrowlBrushedScreenPref, value, GrowlBrushedPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (BOOL) isFloatingIcon {
	BOOL value = GrowlBrushedFloatIconPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlBrushedFloatIconPref, GrowlBrushedPrefDomain, &value);
	return value;
}

- (void) setFloatingIcon:(BOOL)value {
	WRITE_GROWL_PREF_BOOL(GrowlBrushedFloatIconPref, value, GrowlBrushedPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (BOOL) isLimit {
	BOOL value = GrowlBrushedLimitPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlBrushedLimitPref, GrowlBrushedPrefDomain, &value);
	return value;
}

- (void) setLimit:(BOOL)value {
	WRITE_GROWL_PREF_BOOL(GrowlBrushedLimitPref, value, GrowlBrushedPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (BOOL) isAqua {
	BOOL value = GrowlBrushedAquaPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlBrushedAquaPref, GrowlBrushedPrefDomain, &value);
	return value;
}

- (void) setAqua:(BOOL)value {
	WRITE_GROWL_PREF_BOOL(GrowlBrushedAquaPref, value, GrowlBrushedPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (int) size {
	int value = 0;
	READ_GROWL_PREF_INT(GrowlBrushedSizePref, GrowlBrushedPrefDomain, &value);
	return value;
}

- (void) setSize:(int)value {
	WRITE_GROWL_PREF_INT(GrowlBrushedSizePref, value, GrowlBrushedPrefDomain);
	UPDATE_GROWL_PREFS();
}

@end
