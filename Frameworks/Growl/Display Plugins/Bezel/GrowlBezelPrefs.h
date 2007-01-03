//
//  GrowlBezelPrefs.h
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 14/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

#define BezelPrefDomain						@"com.Growl.Bezel"

#define BEZEL_POSITION_PREF					@"Bezel - Position"
#define BEZEL_SIZE_PREF						@"Bezel - Size"
#define BEZEL_OPACITY_PREF					@"Bezel - Opacity"
#define BEZEL_DURATION_PREF					@"Bezel - Duration"
#define BEZEL_SCREEN_PREF					@"Bezel - Screen"
#define BEZEL_STYLE_PREF					@"Bezel - Style"
#define BEZEL_SHRINK_PREF					@"Bezel - Shrink"

#define GrowlBezelVeryLowBackgroundColor	@"Bezel-Priority-VeryLow-Color"
#define GrowlBezelModerateBackgroundColor	@"Bezel-Priority-Moderate-Color"
#define GrowlBezelNormalBackgroundColor		@"Bezel-Priority-Normal-Color"
#define GrowlBezelHighBackgroundColor		@"Bezel-Priority-High-Color"
#define GrowlBezelEmergencyBackgroundColor	@"Bezel-Priority-Emergency-Color"

#define GrowlBezelVeryLowTextColor			@"Bezel-Priority-VeryLow-Text-Color"
#define GrowlBezelModerateTextColor			@"Bezel-Priority-Moderate-Text-Color"
#define GrowlBezelNormalTextColor			@"Bezel-Priority-Normal-Text-Color"
#define GrowlBezelHighTextColor				@"Bezel-Priority-High-Text-Color"
#define GrowlBezelEmergencyTextColor		@"Bezel-Priority-Emergency-Text-Color"

#define BEZEL_OPACITY_DEFAULT				40.0f

#define BEZEL_POSITION_DEFAULT				0
#define BEZEL_POSITION_TOPRIGHT				1
#define BEZEL_POSITION_BOTTOMRIGHT			2
#define BEZEL_POSITION_BOTTOMLEFT			3
#define BEZEL_POSITION_TOPLEFT				4

#define BEZEL_SIZE_NORMAL					0
#define BEZEL_SIZE_SMALL					1

@interface GrowlBezelPrefs : NSPreferencePane {
	IBOutlet NSSlider		*slider_opacity;
}

- (float) duration;
- (void) setDuration:(float)value;
- (float) opacity;
- (void) setOpacity:(float)value;
- (int) size;
- (void) setSize:(int)value;
- (int) style;
- (void) setStyle:(int)value;
- (int) screen;
- (void) setScreen:(int)value;
- (int) position;
- (void) setPosition:(int)value;

- (NSColor *) textColorVeryLow;
- (void) setTextColorVeryLow:(NSColor *)value;
- (NSColor *) textColorModerate;
- (void) setTextColorModerate:(NSColor *)value;
- (NSColor *) textColorNormal;
- (void) setTextColorNormal:(NSColor *)value;
- (NSColor *) textColorHigh;
- (void) setTextColorHigh:(NSColor *)value;
- (NSColor *) textColorEmergency;
- (void) setTextColorEmergency:(NSColor *)value;

- (NSColor *) backgroundColorVeryLow;
- (void) setBackgroundColorVeryLow:(NSColor *)value;
- (NSColor *) backgroundColorModerate;
- (void) setBackgroundColorModerate:(NSColor *)value;
- (NSColor *) backgroundColorNormal;
- (void) setBackgroundColorNormal:(NSColor *)value;
- (NSColor *) backgroundColorHigh;
- (void) setBackgroundColorHigh:(NSColor *)value;
- (NSColor *) backgroundColorEmergency;
- (void) setBackgroundColorEmergency:(NSColor *)value;

@end
