//
//  GrowlSmokeWindowController.m
//  Display Plugins
//
//  Created by Matthew Walton on 11/09/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
//  Most of this is lifted from KABubbleWindowController in the Growl source

#import "GrowlSmokeWindowController.h"
#import "GrowlSmokeWindowView.h"
#import "GrowlSmokeDefines.h"
#import "GrowlDefinesInternal.h"
#import "NSWindow+Transforms.h"

static unsigned globalId = 0U;

@implementation GrowlSmokeWindowController

static const double gAdditionalLinesDisplayTime = 0.5;
static const double gMaxDisplayTime = 10.0;
static NSMutableDictionary *notificationsByIdentifier;

#pragma mark Delegate Methods
/*
	These methods are the methods that this class calls on the delegate.  In this case
	this class is the delegate for the class
*/

- (void) didFadeOut:(FadingWindowController *)sender {
#pragma unused(sender)
	NSSize windowSize = [[self window] frame].size;
//	NSLog(@"self id: [%d]", self->uid);

	// stop depth wrapping around
	if (windowSize.height > depth) {
		depth = 0U;
	} else {
		depth -= windowSize.height;
	}

	NSNumber *idValue = [[NSNumber alloc] initWithUnsignedInt:uid];
	NSNumber *depthValue = [[NSNumber alloc] initWithInt:depth];
	NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
		idValue,    @"ID",
		depthValue, @"Depth",
		nil];
	[idValue    release];
	[depthValue release];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"Glide" object:nil userInfo:dict];
	[nc postNotificationName:@"SmokeGone" object:nil userInfo:dict];
	[dict release];
}

- (void) _glideUp:(NSNotification *)note {
	NSDictionary *userInfo = [note userInfo];
//	NSLog(@"id: %d depth: %f", [[userInfo objectForKey:@"ID"] unsignedIntValue], [[userInfo objectForKey:@"Depth"] floatValue]);
//	NSLog(@"self id: %d smokeWindowDepth: %d", uid, smokeWindowDepth);
	if ([[userInfo objectForKey:@"ID"] unsignedIntValue] < uid) {
		NSWindow *window = [self window];
		NSRect theFrame = [window frame];
		theFrame.origin.y += [[[note userInfo] objectForKey:@"Depth"] floatValue];
		// don't allow notification to fly off the top of the screen
		if (theFrame.origin.y < NSMaxY( [[self screen] visibleFrame] ) - GrowlSmokePadding) {
			[window setFrame:theFrame display:NO animate:YES];
			NSNumber *idValue = [[NSNumber alloc] initWithUnsignedInt:uid];
			NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
				idValue, @"ID",
				[NSValue valueWithRect:theFrame], @"Space",
				nil];
			[idValue release];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"Clear Space" object:nil userInfo:dict];
			[dict release];
		}
	}
}

- (void) _clearSpace:(NSNotification *)note {
	NSDictionary *userInfo = [note userInfo];
	unsigned i = [[userInfo objectForKey:@"ID"] unsignedIntValue];
	NSRect space = [[userInfo objectForKey:@"Space"] rectValue];
	NSWindow *window = [self window];
	NSRect theFrame = [window frame];
	/*NSLog(@"Notification %u (%f, %f, %f, %f) received clear space message from notification %u (%f, %f, %f, %f)\n",
		  uid, i,
		  theFrame.origin.x, theFrame.origin.y, theFrame.size.width, theFrame.size.height,
		  space.origin.x, space.origin.y, space.size.width, space.size.height);*/
	if (i != uid && NSIntersectsRect(space, theFrame)) {
		//NSLog(@"I intersect with this frame\n");
		theFrame.origin.y = space.origin.y - space.size.height - GrowlSmokePadding;
		//NSLog(@"New origin: (%f, %f)\n", theFrame.origin.x, theFrame.origin.y);
		[window setFrame:theFrame display:NO animate:YES];
		NSNumber *idValue = [[NSNumber alloc] initWithUnsignedInt:uid];
		NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
			idValue, @"ID",
			[NSValue valueWithRect:theFrame], @"Space",
			nil];
		[idValue release];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"Clear Space" object:nil userInfo:dict];
		[dict release];
	}
}

#pragma mark Regularly Scheduled Coding

- (id) initWithTitle:(NSString *) title text:(NSString *) text icon:(NSImage *) icon priority:(int) priority sticky:(BOOL) sticky depth:(unsigned)theDepth identifier:(NSString *)ident {
	uid = globalId++;
	identifier = [ident retain];
	GrowlSmokeWindowController *oldController = [notificationsByIdentifier objectForKey:identifier];
	if (oldController) {
		// coalescing
		GrowlSmokeWindowView *view = (GrowlSmokeWindowView *)[[oldController window] contentView];
		[view setPriority:priority];
		[view setTitle:title];
		[view setText:text];
		[view setIcon:icon];
		[self release];
		self = oldController;
		return self;
	}
	depth = theDepth;

	screenNumber = 0U;
	READ_GROWL_PREF_INT(GrowlSmokeScreenPref, GrowlSmokePrefDomain, &screenNumber);

	/*[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector( _glideUp: )
												name:@"Glide"
											  object:nil];*/

	NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect( 0.0f, 0.0f, GrowlSmokeNotificationWidth, 65.0f )
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

	GrowlSmokeWindowView *view = [[GrowlSmokeWindowView alloc] initWithFrame:panelFrame];
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

	[panel setFrameTopLeftPoint:NSMakePoint(NSMaxX(screen) - NSWidth( panelFrame ) - GrowlSmokePadding,
											NSMaxY(screen) - GrowlSmokePadding - depth)];

	if ((self = [super initWithWindow:panel])) {
		depth += NSHeight( panelFrame );
		autoFadeOut = !sticky;
		delegate = self;

		// the visibility time for this notification should be the minimum display time plus
		// some multiple of gAdditionalLinesDisplayTime, not to exceed gMaxDisplayTime
		int rowCount = [view descriptionRowCount];
		if (rowCount <= 2) {
			rowCount = 0;
		}
		float duration = GrowlSmokeDurationPrefDefault;
		READ_GROWL_PREF_FLOAT(GrowlSmokeDurationPref, GrowlSmokePrefDomain, &duration);
		/*BOOL limitPref = YES;
		READ_GROWL_PREF_BOOL(GrowlSmokeLimitPref, GrowlSmokePrefDomain, &limitPref);
		if (!limitPref) {*/
			displayTime = MIN (duration + rowCount * gAdditionalLinesDisplayTime,
								gMaxDisplayTime);
		/*} else {
			displayTime = gMinDisplayTime;
		}*/

		NSNumber *idValue = [[NSNumber alloc] initWithUnsignedInt:uid];
		NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:
			idValue, @"ID",
			[NSValue valueWithRect:[[self window] frame]], @"Space",
			nil];
		[idValue release];
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"Clear Space" object:nil userInfo:dict];
		[dict release];
		[nc addObserver:self
			   selector:@selector(_clearSpace:)
				   name:@"Clear Space"
				 object:nil];

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
	GrowlSmokeWindowView *view = (GrowlSmokeWindowView *)[[self window] contentView];
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	//extern unsigned smokeWindowDepth;
//	NSLog(@"smokeController deallocking");
	//if ( depth == smokeWindowDepth )
	// 	smokeWindowDepth = 0;

	NSWindow *myWindow = [self window];
	[[myWindow contentView] release];
	[myWindow release];

	[super dealloc];
}

#pragma mark -

- (unsigned)depth {
	return depth;
}

@end
