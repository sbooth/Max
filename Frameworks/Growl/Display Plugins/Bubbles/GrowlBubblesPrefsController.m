//
//  GrowlBubblesPrefsController.m
//  Growl
//
//  Created by Kevin Ballard on 9/7/04.
//  Copyright 2004 TildeSoft. All rights reserved.
//

#import "GrowlBubblesPrefsController.h"
#import "GrowlBubblesDefines.h"
#import "GrowlDefinesInternal.h"

@implementation GrowlBubblesPrefsController
- (NSString *) mainNibName {
	return @"BubblesPrefs";
}

+ (void) loadColorWell:(NSColorWell *)colorWell fromKey:(NSString *)key defaultColor:(NSColor *)defaultColor {
	NSData *data = nil;
	NSColor *color;
	READ_GROWL_PREF_VALUE(key, GrowlBubblesPrefDomain, NSData *, &data);
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
	NSColor *defaultColor = [NSColor colorWithCalibratedRed:0.69412f green:0.83147f blue:0.96078f alpha:1.0f];

	[GrowlBubblesPrefsController loadColorWell:color_veryLow fromKey:GrowlBubblesVeryLowColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:color_moderate fromKey:GrowlBubblesModerateColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:color_normal fromKey:GrowlBubblesNormalColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:color_high fromKey:GrowlBubblesHighColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:color_emergency fromKey:GrowlBubblesEmergencyColor defaultColor:defaultColor];

	defaultColor = [[NSColor controlTextColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	[GrowlBubblesPrefsController loadColorWell:text_veryLow fromKey:GrowlBubblesVeryLowTextColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:text_moderate fromKey:GrowlBubblesModerateTextColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:text_normal fromKey:GrowlBubblesNormalTextColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:text_high fromKey:GrowlBubblesHighTextColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:text_emergency fromKey:GrowlBubblesEmergencyTextColor defaultColor:defaultColor];

	defaultColor = [NSColor colorWithCalibratedRed:0.93725f green:0.96863f blue:0.99216f alpha:0.95f];

	[GrowlBubblesPrefsController loadColorWell:top_veryLow fromKey:GrowlBubblesVeryLowTopColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:top_moderate fromKey:GrowlBubblesModerateTopColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:top_normal fromKey:GrowlBubblesNormalTopColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:top_high fromKey:GrowlBubblesHighTopColor defaultColor:defaultColor];
	[GrowlBubblesPrefsController loadColorWell:top_emergency fromKey:GrowlBubblesEmergencyTopColor defaultColor:defaultColor];
}

#pragma mark -

- (BOOL) isLimit {
	BOOL value = YES;
	READ_GROWL_PREF_BOOL(GrowlBubblesLimitPref, GrowlBubblesPrefDomain, &value);
	return value;
}

- (void) setLimit:(BOOL)value {
	WRITE_GROWL_PREF_BOOL(GrowlBubblesLimitPref, value, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (float) opacity {
	float value = 95.0f;
	READ_GROWL_PREF_FLOAT(GrowlBubblesOpacity, GrowlBubblesPrefDomain, &value);
	return value;
}

- (void) setOpacity:(float)value {
	WRITE_GROWL_PREF_FLOAT(GrowlBubblesOpacity, value, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (float) duration {
	float value = 4.0f;
	READ_GROWL_PREF_FLOAT(GrowlBubblesDuration, GrowlBubblesPrefDomain, &value);
	return value;
}

- (void) setDuration:(float)value {
	WRITE_GROWL_PREF_FLOAT(GrowlBubblesDuration, value, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}

#pragma mark -

- (IBAction) topColorChanged:(id)sender {
	NSColor *color;
	NSString *key;
	switch ([sender tag]) {
		case -2:
			key = GrowlBubblesVeryLowTopColor;
			break;
		case -1:
			key = GrowlBubblesModerateTopColor;
			break;
		case 1:
			key = GrowlBubblesHighTopColor;
			break;
		case 2:
			key = GrowlBubblesEmergencyTopColor;
			break;
		case 0:
		default:
			key = GrowlBubblesNormalTopColor;
			break;
	}

	color = [[sender color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSData *theData = [NSArchiver archivedDataWithRootObject:color];
	WRITE_GROWL_PREF_VALUE(key, theData, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (IBAction) colorChanged:(id)sender {
	NSColor *color;
	NSString *key;
	switch ([sender tag]) {
		case -2:
			key = GrowlBubblesVeryLowColor;
			break;
		case -1:
			key = GrowlBubblesModerateColor;
			break;
		case 1:
			key = GrowlBubblesHighColor;
			break;
		case 2:
			key = GrowlBubblesEmergencyColor;
			break;
		case 0:
		default:
			key = GrowlBubblesNormalColor;
			break;
	}

	color = [[sender color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSData *theData = [NSArchiver archivedDataWithRootObject:color];
	WRITE_GROWL_PREF_VALUE(key, theData, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (IBAction) textColorChanged:(id)sender {
	NSString *key;
	switch ([sender tag]) {
		case -2:
			key = GrowlBubblesVeryLowTextColor;
			break;
		case -1:
			key = GrowlBubblesModerateTextColor;
			break;
		case 1:
			key = GrowlBubblesHighTextColor;
			break;
		case 2:
			key = GrowlBubblesEmergencyTextColor;
			break;
		case 0:
		default:
			key = GrowlBubblesNormalTextColor;
			break;
	}

	NSData *theData = [NSArchiver archivedDataWithRootObject:[sender color]];
	WRITE_GROWL_PREF_VALUE(key, theData, GrowlBubblesPrefDomain);
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
	READ_GROWL_PREF_INT(GrowlBubblesScreen, GrowlBubblesPrefDomain, &value);
	return value;
}

- (void) setScreen:(int)value {
	WRITE_GROWL_PREF_INT(GrowlBubblesScreen, value, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}

- (int) size {
	int value = 0;
	READ_GROWL_PREF_INT(GrowlBubblesSizePref, GrowlBubblesPrefDomain, &value);
	return value;
}

- (void) setSize:(int)value {
	WRITE_GROWL_PREF_INT(GrowlBubblesSizePref, value, GrowlBubblesPrefDomain);
	UPDATE_GROWL_PREFS();
}
@end
