//
//  GrowlWebKitWindowView.m
//  Growl
//
//  Created by Ingmar Stein on Thu Apr 14 2005.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import "GrowlWebKitWindowView.h"
#import "GrowlDefinesInternal.h"
#import "GrowlWebKitDefines.h"

@implementation GrowlWebKitWindowView
- (id) initWithFrame:(NSRect)frameRect frameName:(NSString *)frameName groupName:(NSString *)groupName {
	if ((self = [super initWithFrame:frameRect frameName:frameName groupName:groupName])) {
		[self setUIDelegate:self];
	}
	return self;
}

- (void) dealloc {
	[self setUIDelegate:nil];
	[super dealloc];
}

// forward mouseMoved events to subviews but catch all other events here
- (NSView *) hitTest:(NSPoint)aPoint {
	if ([[[self window] currentEvent] type] == NSMouseMoved)
		return [super hitTest:aPoint];

	if ([[self superview] mouse:aPoint inRect:[self frame]])
		return self;

	return nil;
}

#pragma mark -

- (id) target {
	return target;
}

- (void) setTarget:(id) object {
	target = object;
}

#pragma mark -

- (SEL) action {
	return action;
}

- (void) setAction:(SEL) selector {
	action = selector;
}

- (void) sizeToFit {
	NSRect rect = [[[[self mainFrame] frameView] documentView] frame];

	// resize the window so that it contains the tracking rect
	NSRect windowRect = [[self window] frame];
	windowRect.size = rect.size;
	[[self window] setFrame:windowRect display:YES];

	if (trackingRectTag)
		[self removeTrackingRect:trackingRectTag];
	trackingRectTag = [self addTrackingRect:rect owner:self userData:NULL assumeInside:NO];
}

#pragma mark -

- (BOOL) shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent {
#pragma unused(theEvent)
	[NSApp preventWindowOrdering];
	return YES;
}

- (BOOL) mouseOver {
	return mouseOver;
}

- (void) setCloseOnMouseExit:(BOOL)flag {
	closeOnMouseExit = flag;
}

- (BOOL) acceptsFirstMouse:(NSEvent *) event {
#pragma unused(event)
	return YES;
}

- (void) mouseEntered:(NSEvent *)theEvent {
#pragma unused(theEvent)
	// TODO: find a way to receive NSMouseMoved events without activating the app
	if (![NSApp isActive])
		[NSApp activateIgnoringOtherApps:YES];
	[[self window] setAcceptsMouseMovedEvents:YES];
	[[self window] makeKeyWindow];
	mouseOver = YES;
	[self setNeedsDisplay:YES];
}

- (void) mouseExited:(NSEvent *)theEvent {
#pragma unused(theEvent)
	[[self window] setAcceptsMouseMovedEvents:NO];
	mouseOver = NO;
	[self setNeedsDisplay:YES];

	// abuse the target object
	if (closeOnMouseExit && [target respondsToSelector:@selector(startFadeOut)])
		[target performSelector:@selector(startFadeOut)];
}

- (unsigned) webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo {
#pragma unused(sender, draggingInfo)
	return 0U; //WebDragDestinationActionNone;
}

- (unsigned) webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point {
#pragma unused(sender, point)
	return 0U; //WebDragSourceActionNone;
}

- (void) mouseDown:(NSEvent *)event {
#pragma unused(event)
	mouseOver = NO;
	if (target && action && [target respondsToSelector:action])
		[target performSelector:action withObject:self];
}

- (NSArray *) webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
#pragma unused(sender, element, defaultMenuItems)
	// disable context menu
	return nil;
}

@end
