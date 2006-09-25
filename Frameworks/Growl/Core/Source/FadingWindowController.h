//
//  FadingWindowController.h
//  Display Plugins
//
//  Created by Ingmar Stein on 16.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FadingWindowController : NSWindowController
{
	id			delegate;
	NSTimer		*animationTimer;
	BOOL		autoFadeOut;
	BOOL		doFadeIn;
	BOOL		doFadeOut;
	BOOL		isFadingIn;
	BOOL		isFadingOut;
	float		fadeIncrement;
	float		timerInterval;
	double		displayTime;
	BOOL		screenshotMode;
	unsigned	screenNumber;

	SEL			action;
	id			target;
	id			clickContext;
	NSString	*appName;
	NSNumber	*appPid;
}
- (void) startFadeIn;
- (void) startFadeOut;
- (void) stopFadeIn;
- (void) stopFadeOut;

- (BOOL) automaticallyFadeOut;
- (void) setAutomaticallyFadesOut:(BOOL) autoFade;

- (float) fadeIncrement;
- (void) setFadeIncrement:(float)increment;

- (float) timerInterval;
- (void) setTimerInterval:(float)interval;

- (double) displayTime;
- (void) setDisplayTime:(double)t;

- (id) delegate;
- (void) setDelegate:(id)delegate;

- (BOOL) screenshotModeEnabled;
- (void) setScreenshotModeEnabled:(BOOL)newScreenshotMode;
//-takeScreenshot is declared here mainly for the benefit of subclasses.
//you probably don't need to call it if you aren't a subclass.
- (void) takeScreenshot;

- (void) _stopTimer;
- (void) _waitBeforeFadeOut;

- (void) _fadeIn:(NSTimer *)inTimer;
- (void) _fadeOut:(NSTimer *)inTimer;

- (BOOL) isFadingIn;
- (BOOL) isFadingOut;

- (NSScreen *) screen;

- (id) target;
- (void) setTarget:(id)object;

- (SEL) action;
- (void) setAction:(SEL)selector;

- (NSString *) appName;
- (void) setAppName:(NSString *) inAppName;

- (NSNumber *) appPid;
- (void) setAppPid:(NSNumber *) inAppPid;

- (id) clickContext;
- (void) setClickContext:(id) clickContext;
@end

@interface NSObject (FadingWindowControllerDelegate)
- (void) willFadeIn:(FadingWindowController *)controller;
- (void) didFadeIn:(FadingWindowController *)controller;

- (void) willFadeOut:(FadingWindowController *)controller;
- (void) didFadeOut:(FadingWindowController *)controller;
@end
