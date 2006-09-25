//
//  FadingWindowController.m
//  Display Plugins
//
//  Created by Ingmar Stein on 16.11.04.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "FadingWindowController.h"
#import "GrowlPathUtil.h"
#import "GrowlDefines.h"

#define TIMER_INTERVAL (1.0 / 30.0)
#define FADE_INCREMENT 0.05f

@implementation FadingWindowController
- (id) initWithWindow:(NSWindow *)window {
	if ((self = [super initWithWindow:window])) {
		autoFadeOut = NO;
		doFadeIn = YES;
		doFadeOut = YES;
		fadeIncrement = FADE_INCREMENT;
		timerInterval = TIMER_INTERVAL;
	}
	return self;
}

- (void) _stopTimer {
	[animationTimer invalidate];
	[animationTimer release];
	animationTimer = nil;
}

- (void) dealloc {
	[target       release];
	[clickContext release];
	[appName      release];
	[appPid       release];

	[self _stopTimer];
	[super dealloc];
}

- (void) _waitBeforeFadeOut {
	animationTimer = [[NSTimer scheduledTimerWithTimeInterval:displayTime
													   target:self
													 selector:@selector(startFadeOut)
													 userInfo:nil
													  repeats:NO] retain];
}

- (void) _fadeIn:(NSTimer *)inTimer {
#pragma unused(inTimer)
	NSWindow *myWindow = [self window];
	float alpha = [myWindow alphaValue];
	if (alpha < 1.0f) {
		alpha += fadeIncrement;
		if (alpha > 1.0f) {
			alpha = 1.0f;
		}
		[myWindow setAlphaValue:alpha];
	} else {
		[self stopFadeIn];
	}
}

- (void) _fadeOut:(NSTimer *)inTimer {
#pragma unused(inTimer)
	NSWindow *myWindow = [self window];
	float alpha = [myWindow alphaValue];
	if (alpha > 0.0f) {
		alpha -= fadeIncrement;
		if (alpha < 0.0f) {
			alpha = 0.0f;
		}
		[myWindow setAlphaValue:alpha];
	} else {
		[self stopFadeOut];
	}
}

- (void) startFadeIn {
	if (delegate && [delegate respondsToSelector:@selector(willFadeIn:)])
		[delegate willFadeIn:self];
	isFadingIn = YES;
	[self retain]; // release after fade out
	[self showWindow:nil];
	[self _stopTimer];
	if (doFadeIn) {
		animationTimer = [[NSTimer scheduledTimerWithTimeInterval:timerInterval
														   target:self
														 selector:@selector(_fadeIn:)
														 userInfo:nil
														  repeats:YES] retain];
		//Start immediately
		[self _fadeIn:nil];
	} else {
		[self stopFadeIn];
	}
}

- (void) stopFadeIn {
	isFadingIn = NO;
	[self _stopTimer];
	if (delegate && [delegate respondsToSelector:@selector(didFadeIn:)])
		[delegate didFadeIn:self];
	if (screenshotMode)
		[self takeScreenshot];
	if (autoFadeOut)
		[self _waitBeforeFadeOut];
}

- (void) startFadeOut {
	if (delegate && [delegate respondsToSelector:@selector(willFadeOut:)])
		[delegate willFadeOut:self];
	isFadingOut = YES;
	[self _stopTimer];
	if (doFadeOut) {
		animationTimer = [[NSTimer scheduledTimerWithTimeInterval:timerInterval
														   target:self
														 selector:@selector(_fadeOut:)
														 userInfo:nil
														  repeats:YES] retain];
		//Start immediately
		[self _fadeOut:nil];
	} else {
		[self stopFadeOut];
	}
}

- (void) stopFadeOut {
	isFadingOut = NO;
	[self _stopTimer];
	if (delegate && [delegate respondsToSelector:@selector(didFadeOut:)])
		[delegate didFadeOut:self];

	if (clickContext) {
		NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
			clickContext, GROWL_KEY_CLICKED_CONTEXT,
			appPid,       GROWL_APP_PID,
			nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:GROWL_NOTIFICATION_TIMED_OUT
															object:appName
														  userInfo:userInfo];
		[userInfo release];

		//Avoid duplicate click messages by immediately clearing the clickContext
		clickContext = nil;
	}

	[self close];	// close our window
	[self release];	// we retained when we fade in
}

#pragma mark -

- (BOOL) automaticallyFadeOut {
	return autoFadeOut;
}

- (void) setAutomaticallyFadesOut:(BOOL)autoFade {
	autoFadeOut = autoFade;
}

#pragma mark -

- (float) fadeIncrement {
	return fadeIncrement;
}

- (void) setFadeIncrement:(float)increment {
	fadeIncrement = increment;
}

#pragma mark -

- (BOOL) isFadingIn {
	return isFadingIn;
}

- (BOOL) isFadingOut {
	return isFadingOut;
}

#pragma mark -

- (float) timerInterval {
	return timerInterval;
}

- (void) setTimerInterval:(float) interval {
	timerInterval = interval;
}

#pragma mark -

- (double) displayTime {
	return displayTime;
}

- (void) setDisplayTime:(double) t {
	displayTime = t;
}

#pragma mark -

- (id) delegate {
	return delegate;
}

- (void) setDelegate:(id) object {
	delegate = object;
}

#pragma mark -

- (BOOL) screenshotModeEnabled {
	return screenshotMode;
}

- (void) setScreenshotModeEnabled:(BOOL)newScreenshotMode {
	screenshotMode = newScreenshotMode;
}

- (void) takeScreenshot {
	NSView *view = [[self window] contentView];
	NSRect rect = [view bounds];
	[view lockFocus];
	NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:rect];
	[view unlockFocus];

	NSData *pngData = [bitmap representationUsingType:NSPNGFileType
										   properties:nil];
	[bitmap release];

	NSString *path = [[[GrowlPathUtil screenshotsDirectory] stringByAppendingPathComponent:[GrowlPathUtil nextScreenshotName]] stringByAppendingPathExtension:@"png"];
	[pngData writeToFile:path atomically:NO];
}

#pragma mark -

- (NSScreen *) screen {
	NSArray *screens = [NSScreen screens];
	if (screenNumber < [screens count])
		return [screens objectAtIndex:screenNumber];
	else
		return [NSScreen mainScreen];
}

#pragma mark -

- (id) target {
	return target;
}

- (void) setTarget:(id) object {
	[target autorelease];
	target = [object retain];
}

#pragma mark -

- (SEL) action {
	return action;
}

- (void) setAction:(SEL) selector {
	action = selector;
}

#pragma mark -

- (NSString *) appName {
	return appName;
}

- (void) setAppName:(NSString *)inAppName {
	if (inAppName != appName) {
		[appName release];
		appName = [inAppName retain];
	}
}

#pragma mark -

- (NSNumber *) appPid {
	return appPid;
}

- (void) setAppPid:(NSNumber *)inAppPid {
	if (inAppPid != appPid) {
		[appPid release];
		appPid = [inAppPid retain];
	}
}

#pragma mark -

- (id) clickContext {
	return clickContext;
}

- (void) setClickContext:(id)inClickContext {
	[clickContext autorelease];
	clickContext = [inClickContext retain];
}

#pragma mark -

- (void) _notificationClicked:(id)sender {
#pragma unused(sender)
	if (target && action && [target respondsToSelector:action])
		[target performSelector:action withObject:self];
	[self startFadeOut];
}

@end
