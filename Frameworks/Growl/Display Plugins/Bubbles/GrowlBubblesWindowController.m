//
//  GrowlBubblesWindowController.m
//  Growl
//
//  Created by Nelson Elhage on Wed Jun 09 2004.
//  Name changed from KABubbleWindowController.m by Justin Burns on Fri Nov 05 2004.
//  Copyright (c) 2004 Nelson Elhage. All rights reserved.
//

#import "GrowlBubblesWindowController.h"
#import "GrowlBubblesWindowView.h"
#import "GrowlBubblesPrefsController.h"
#import "GrowlBubblesDefines.h"
#import "NSWindow+Transforms.h"

static unsigned bubbleWindowDepth = 0U;
static NSMutableDictionary *notificationsByIdentifier;

@implementation GrowlBubblesWindowController

#define MIN_DISPLAY_TIME				4.0
#define ADDITIONAL_LINES_DISPLAY_TIME	0.5
#define MAX_DISPLAY_TIME				10.0
#define GrowlBubblesPadding				5.0f

#pragma mark -

- (id) initWithTitle:(NSString *) title text:(NSString *) text icon:(NSImage *) icon priority:(int)priority sticky:(BOOL) sticky identifier:(NSString *)ident {
	identifier = [ident retain];
	GrowlBubblesWindowController *oldController = [notificationsByIdentifier objectForKey:identifier];
	if (oldController) {
		// coalescing
		GrowlBubblesWindowView *view = (GrowlBubblesWindowView *)[[oldController window] contentView];
		[view setPriority:priority];
		[view setTitle:title];
		[view setText:text];
		[view setIcon:icon];
		[self release];
		self = oldController;
		return self;
	}

	screenNumber = 0U;
	READ_GROWL_PREF_INT(GrowlBubblesScreen, GrowlBubblesPrefDomain, &screenNumber);

	// I tried setting the width/height to zero, since the view resizes itself later.
	// This made it ignore the alpha at the edges (using 1.0 instead). Why?
	// A window with a frame of NSZeroRect is off-screen and doesn't respect opacity even
	// if moved on screen later. -Evan
	NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect( 0.0f, 0.0f, 270.0f, 65.0f )
												styleMask:NSBorderlessWindowMask | NSNonactivatingPanelMask
												  backing:NSBackingStoreBuffered
													defer:NO];
	NSRect panelFrame = [panel frame];
	[panel setBecomesKeyOnlyIfNeeded:YES];
	[panel setHidesOnDeactivate:NO];
	[panel setBackgroundColor:[NSColor clearColor]];
	[panel setLevel:NSStatusWindowLevel];
	[panel setSticky:YES];
	[panel setAlphaValue:0.0f];
	[panel setOpaque:NO];
	[panel setHasShadow:YES];
	[panel setCanHide:NO];
	[panel setOneShot:YES];
	[panel useOptimizedDrawing:YES];
	//[panel setReleasedWhenClosed:YES]; // ignored for windows owned by window controllers.
	//[panel setDelegate:self];

	GrowlBubblesWindowView *view = [[GrowlBubblesWindowView alloc] initWithFrame:panelFrame];
	[view setTarget:self];
	[view setAction:@selector(_notificationClicked:)];
	[panel setContentView:view];

	[view setPriority:priority];
	[view setTitle:title];
	[view setText:text];
	[view setIcon:icon];

	panelFrame = [view frame];
	[panel setFrame:panelFrame display:NO];

	NSRect screen = [[self screen] visibleFrame];

	[panel setFrameTopLeftPoint:NSMakePoint( NSMaxX(screen) - NSWidth(panelFrame) - GrowlBubblesPadding,
											 NSMaxY(screen) - GrowlBubblesPadding - bubbleWindowDepth )];

	if ((self = [super initWithWindow:panel])) {
		#warning this is some temporary code to to stop notifications from spilling off the bottom of the visible screen area
		// It actually doesn't even stop _this_ notification from spilling off the bottom; just the next one.
		if (NSMinY(panelFrame) < 0.0f) {
			depth = bubbleWindowDepth = 0U;
		} else {
			depth = bubbleWindowDepth += NSHeight(panelFrame) + GrowlBubblesPadding;
		}
		autoFadeOut = !sticky;
		delegate = self;

		// the visibility time for this bubble should be the minimum display time plus
		// some multiple of ADDITIONAL_LINES_DISPLAY_TIME, not to exceed MAX_DISPLAY_TIME
		int rowCount = MIN ([view descriptionRowCount], 0) - 2;
		BOOL limitPref = YES;
		READ_GROWL_PREF_BOOL(GrowlBubblesLimitPref, GrowlBubblesPrefDomain, &limitPref);
		float duration = MIN_DISPLAY_TIME;
		READ_GROWL_PREF_FLOAT(GrowlBubblesDuration, GrowlBubblesPrefDomain, &duration);
		if (!limitPref) {
			displayTime = MIN (duration + rowCount * ADDITIONAL_LINES_DISPLAY_TIME,
							   MAX_DISPLAY_TIME);
		} else {
			displayTime = duration;
		}

		if (identifier) {
			if (!notificationsByIdentifier) {
				notificationsByIdentifier = [[NSMutableDictionary alloc] init];
			}
			[notificationsByIdentifier setObject:self forKey:identifier];
		}
	}

	return self;
}

- (void) startFadeOut {
	GrowlBubblesWindowView *view = (GrowlBubblesWindowView *)[[self window] contentView];
	if ([view mouseOver]) {
		[view setCloseOnMouseExit:YES];
	} else {
		[super startFadeOut];
	}
}

- (void) stopFadeOut {
	if (identifier) {
		[notificationsByIdentifier removeObjectForKey:identifier];
		[identifier release];
	}
	[super stopFadeOut];
}

- (void) dealloc {
	if (depth == bubbleWindowDepth) {
		bubbleWindowDepth = 0U;
	}
	NSWindow *myWindow = [self window];
	[[myWindow contentView] release];
	[myWindow release];

	[super dealloc];
}

@end
