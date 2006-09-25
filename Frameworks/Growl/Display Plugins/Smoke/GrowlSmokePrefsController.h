//
//  GrowlSmokePrefsController.h
//  Display Plugins
//
//  Created by Matthew Walton on 11/09/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

@interface GrowlSmokePrefsController : NSPreferencePane {
	IBOutlet NSSlider		*slider_opacity;

	IBOutlet NSColorWell	*color_veryLow;
	IBOutlet NSColorWell	*color_moderate;
	IBOutlet NSColorWell	*color_normal;
	IBOutlet NSColorWell	*color_high;
	IBOutlet NSColorWell	*color_emergency;

	IBOutlet NSColorWell	*text_veryLow;
	IBOutlet NSColorWell	*text_moderate;
	IBOutlet NSColorWell	*text_normal;
	IBOutlet NSColorWell	*text_high;
	IBOutlet NSColorWell	*text_emergency;
}

- (float) duration;
- (void) setDuration:(float)value;
- (float) opacity;
- (void) setOpacity:(float)value;
- (BOOL) isLimit;
- (void) setLimit:(BOOL)value;
- (BOOL) isFloatingIcon;
- (void) setFloatingIcon:(BOOL)value;
- (int) screen;
- (void) setScreen:(int)value;
- (int) size;
- (void) setSize:(int)value;
- (IBAction) colorChanged:(id)sender;
- (IBAction) textColorChanged:(id)sender;

@end
