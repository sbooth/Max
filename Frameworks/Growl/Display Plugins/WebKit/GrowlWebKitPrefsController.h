//
//  GrowlWebKitPrefsController.h
//  Growl
//
//  Created by Ingmar Stein on Thu Apr 14 2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

@interface GrowlWebKitPrefsController : NSPreferencePane {
	IBOutlet NSSlider		*slider_opacity;
	NSString				*style;
	NSString				*prefDomain;
}
- (id) initWithStyle:(NSString *)style;
- (float) duration;
- (void) setDuration:(float)value;
- (float) opacity;
- (void) setOpacity:(float)value;
- (BOOL) isLimit;
- (void) setLimit:(BOOL)value;
- (int) screen;
- (void) setScreen:(int)value;

@end
