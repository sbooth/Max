//
//  GrowlMusicVideoPrefs.h
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 14/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

#define MusicVideoPrefDomain			@"com.Growl.MusicVideo"

#define MUSICVIDEO_SCREEN_PREF			@"Screen"

#define MUSICVIDEO_OPACITY_PREF			@"Opacity"
#define MUSICVIDEO_DEFAULT_OPACITY		60.0f

#define MUSICVIDEO_DURATION_PREF		@"Duration"
#define MUSICVIDEO_DEFAULT_DURATION		4.0f

#define MUSICVIDEO_SIZE_PREF			@"Size"
#define MUSICVIDEO_SIZE_NORMAL			0
#define MUSICVIDEO_SIZE_HUGE			1

#define MUSICVIDEO_EFFECT_PREF			@"Transition effect"
#define MUSICVIDEO_EFFECT_SLIDE			0
#define MUSICVIDEO_EFFECT_WIPE			1

#define GrowlMusicVideoVeryLowBackgroundColor	@"MusicVideo-Priority-VeryLow-Color"
#define GrowlMusicVideoModerateBackgroundColor	@"MusicVideo-Priority-Moderate-Color"
#define GrowlMusicVideoNormalBackgroundColor	@"MusicVideo-Priority-Normal-Color"
#define GrowlMusicVideoHighBackgroundColor		@"MusicVideo-Priority-High-Color"
#define GrowlMusicVideoEmergencyBackgroundColor	@"MusicVideo-Priority-Emergency-Color"

#define GrowlMusicVideoVeryLowTextColor			@"MusicVideo-Priority-VeryLow-Text-Color"
#define GrowlMusicVideoModerateTextColor		@"MusicVideo-Priority-Moderate-Text-Color"
#define GrowlMusicVideoNormalTextColor			@"MusicVideo-Priority-Normal-Text-Color"
#define GrowlMusicVideoHighTextColor			@"MusicVideo-Priority-High-Text-Color"
#define GrowlMusicVideoEmergencyTextColor		@"MusicVideo-Priority-Emergency-Text-Color"

@interface GrowlMusicVideoPrefs : NSPreferencePane {
	IBOutlet NSSlider *slider_opacity;
}

- (float) duration;
- (void) setDuration:(float)value;
- (unsigned) effect;
- (void) setEffect:(unsigned)newEffect;
- (float) opacity;
- (void) setOpacity:(float)value;
- (int) size;
- (void) setSize:(int)value;
- (int) screen;
- (void) setScreen:(int)value;

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
