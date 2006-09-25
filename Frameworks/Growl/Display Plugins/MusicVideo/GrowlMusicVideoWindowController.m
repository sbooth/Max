//
//  GrowlMusicVideoWindowController.m
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 09/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "GrowlMusicVideoWindowController.h"
#import "GrowlMusicVideoWindowView.h"
#import "GrowlMusicVideoPrefs.h"
#import "NSWindow+Transforms.h"

@implementation GrowlMusicVideoWindowController

- (id) initWithTitle:(NSString *)title text:(NSString *)text icon:(NSImage *)icon priority:(int)prio identifier:(NSString *)ident {
	identifier = [ident retain];

	int sizePref = MUSICVIDEO_SIZE_NORMAL;
	float duration = MUSICVIDEO_DEFAULT_DURATION;

	screenNumber = 0U;
	READ_GROWL_PREF_INT(MUSICVIDEO_SCREEN_PREF, MusicVideoPrefDomain, &screenNumber);

	NSRect sizeRect;
	NSRect screen = [[self screen] frame];
	READ_GROWL_PREF_INT(MUSICVIDEO_SIZE_PREF, MusicVideoPrefDomain, &sizePref);
	sizeRect.origin = screen.origin;
	sizeRect.size.width = screen.size.width;
	if (sizePref == MUSICVIDEO_SIZE_HUGE) {
		sizeRect.size.height = 192.0f;
	} else {
		sizeRect.size.height = 96.0f;
	}
	frameHeight = sizeRect.size.height;
	READ_GROWL_PREF_FLOAT(MUSICVIDEO_DURATION_PREF, MusicVideoPrefDomain, &duration);
	READ_GROWL_PREF_INT(MUSICVIDEO_SIZE_PREF, MusicVideoPrefDomain, &sizePref);
	NSPanel *panel = [[NSPanel alloc] initWithContentRect:sizeRect
												styleMask:NSBorderlessWindowMask
												  backing:NSBackingStoreBuffered
													defer:NO];
	NSRect panelFrame = [panel frame];
	[panel setBecomesKeyOnlyIfNeeded:YES];
	[panel setHidesOnDeactivate:NO];
	[panel setBackgroundColor:[NSColor clearColor]];
	[panel setLevel:NSStatusWindowLevel];
	[panel setIgnoresMouseEvents:YES];
	[panel setSticky:YES];
	[panel setOpaque:NO];
	[panel setHasShadow:NO];
	[panel setCanHide:NO];
	[panel setOneShot:YES];
	[panel useOptimizedDrawing:YES];
	//[panel setReleasedWhenClosed:YES]; // ignored for windows owned by window controllers.
	//[panel setDelegate:self];

	GrowlMusicVideoWindowView *view = [[GrowlMusicVideoWindowView alloc] initWithFrame:panelFrame];

	[view setTarget:self];
	[view setAction:@selector(_notificationClicked:)]; // Not used for now

	contentView = [[NSView alloc] initWithFrame:panelFrame];
	[contentView addSubview:view]; // retains subview
	[view release];
	subview = view;
	[panel setContentView:contentView];

	[view setPriority:prio];
	[view setTitle:title];
	[self setText:text];
	[view setIcon:icon];

	panelFrame.origin = screen.origin;
	panelFrame.size.width = screen.size.width;
	panelFrame.size.height = frameHeight;
	[panel setFrame:panelFrame display:NO];

	frameOrigin.x = 0.0f;
	frameOrigin.y = -frameHeight;
	[subview setFrameOrigin:frameOrigin];

	if ((self = [super initWithWindow:panel])) {
		autoFadeOut = YES;
		displayTime = duration;
		priority = prio;
		if (sizePref == MUSICVIDEO_SIZE_HUGE) {
			timerInterval = (1.0 / 128.0);
			fadeIncrement = 6.0f;
		} else {
			timerInterval = (1.0 / 64.0);
			fadeIncrement = 6.0f;
		}
	}

	return self;
}

#pragma mark -
#pragma mark Fading

- (void) stopFadeIn {
	if (!doFadeIn) {
		frameOrigin.y = 0.0f;
		[subview setFrameOrigin:frameOrigin];
		[contentView setNeedsDisplay:YES];
	}
	[super stopFadeIn];
}

- (void) _fadeIn:(NSTimer *)inTimer {
#pragma unused(inTimer)
	if (frameOrigin.y < 0.0f) {
		frameOrigin.y += fadeIncrement;
		[subview setFrameOrigin:frameOrigin];
		[contentView setNeedsDisplay:YES];
	} else {
		[self stopFadeIn];
	}
}

- (void) _fadeOut:(NSTimer *)inTimer {
#pragma unused(inTimer)
	if (frameOrigin.y > -frameHeight) {
		frameOrigin.y -= fadeIncrement;
		[subview setFrameOrigin:frameOrigin];
		[contentView setNeedsDisplay:YES];
	} else {
		[self stopFadeOut];
	}
}

#pragma mark -

- (void) dealloc {
	[identifier    release];
	[contentView   release];
	[[self window] release];
	[super dealloc];
}

#pragma mark Accessors

- (NSString *) identifier {
	return identifier;
}

#pragma mark -

- (int) priority {
	return priority;
}

- (void) setPriority:(int)newPriority {
	priority = newPriority;
	[subview setPriority:priority];
}

- (void) setTitle:(NSString *)title {
	[subview setTitle:title];
}

- (void) setText:(NSString *)text {
	// Sanity check to unify line endings
	NSMutableString	*tempText = [[NSMutableString alloc] initWithString:text];
	[tempText replaceOccurrencesOfString:@"\r"
							  withString:@"\n"
								 options:nil
								   range:NSMakeRange(0U, [tempText length])];
	[subview setText:tempText];
	[tempText release];
}

- (void) setIcon:(NSImage *)icon {
	[subview setIcon:icon];
}

@end
