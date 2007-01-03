//
//  GrowlBrushedWindowView.m
//  Display Plugins
//
//  Created by Ingmar Stein on 12/01/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlBrushedWindowView.h"
#import "GrowlBrushedDefines.h"
#import "GrowlDefinesInternal.h"
#import "GrowlImageAdditions.h"
#import "GrowlBezierPathAdditions.h"

#define GrowlBrushedTextAreaWidth	(GrowlBrushedNotificationWidth - GrowlBrushedPadding - iconSize - GrowlBrushedIconTextPadding - GrowlBrushedPadding)
#define GrowlBrushedMinTextHeight	(GrowlBrushedPadding + iconSize + GrowlBrushedPadding)

@implementation GrowlBrushedWindowView

- (id) initWithFrame:(NSRect) frame {
	if ((self = [super initWithFrame:frame])) {
		textFont = [[NSFont systemFontOfSize:GrowlBrushedTextFontSize] retain];
		textLayoutManager = [[NSLayoutManager alloc] init];
		titleLayoutManager = [[NSLayoutManager alloc] init];
		lineHeight = [textLayoutManager defaultLineHeightForFont:textFont];
		textShadow = [[NSShadow alloc] init];
		[textShadow setShadowOffset:NSMakeSize(0.0f, -2.0f)];
		[textShadow setShadowBlurRadius:3.0f];
		[textShadow setShadowColor:[[[self window] backgroundColor] blendedColorWithFraction:0.5f
																					 ofColor:[NSColor blackColor]]];

		int size = GrowlBrushedSizePrefDefault;
		READ_GROWL_PREF_INT(GrowlBrushedSizePref, GrowlBrushedPrefDomain, &size);
		if (size == GrowlBrushedSizeLarge) {
			iconSize = GrowlBrushedIconSizeLarge;
		} else {
			iconSize = GrowlBrushedIconSize;
		}
	}

	return self;
}

- (void) dealloc {
	[textFont           release];
	[icon               release];
	[textColor          release];
	[textShadow         release];
	[textStorage        release];
	[textLayoutManager  release];
	[titleStorage       release];
	[titleLayoutManager release];

	[super dealloc];
}

- (BOOL)isFlipped {
	// Coordinates are based on top left corner
    return YES;
}

- (void) drawRect:(NSRect)rect {
#pragma unused(rect)
	NSRect bounds = [self bounds];

	// clear the window
	[[NSColor clearColor] set];
	NSRectFill(bounds);

	// calculate bounds based on icon-float pref on or off
	NSRect shadedBounds;
	BOOL floatIcon = GrowlBrushedFloatIconPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlBrushedFloatIconPref, GrowlBrushedPrefDomain, &floatIcon);
	if (floatIcon) {
		float sizeReduction = GrowlBrushedPadding + iconSize + (GrowlBrushedIconTextPadding * 0.5f);

		shadedBounds = NSMakeRect(bounds.origin.x + sizeReduction,
								  bounds.origin.y,
								  bounds.size.width - sizeReduction,
								  bounds.size.height);
	} else {
		shadedBounds = bounds;
	}

	// set up bezier path for rounded corners
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(shadedBounds, 1.0f, 1.0f)
														  radius:GrowlBrushedBorderRadius];
	[path setLineWidth:2.0f];

	NSGraphicsContext *graphicsContext = [NSGraphicsContext currentContext];
	[graphicsContext saveGraphicsState];

	// clip graphics context to path
	[path setClip];

	// fill clipped graphics context with our background colour
	NSWindow *window = [self window];
	NSColor *bgColor = [window backgroundColor];
	[bgColor set];
	NSRectFill(bounds);

	// revert to unclipped graphics context
	[graphicsContext restoreGraphicsState];

	if (mouseOver) {
		[[NSColor keyboardFocusIndicatorColor] set];
		[path stroke];
	}

	// draw the title and the text
	NSRect drawRect;
	drawRect.origin.x = GrowlBrushedPadding;
	drawRect.origin.y = GrowlBrushedPadding;
	drawRect.size.width = iconSize;
	drawRect.size.height = iconSize;

	[icon setFlipped:YES];
	[icon drawScaledInRect:drawRect
				 operation:NSCompositeSourceOver
				  fraction:1.0f];

	drawRect.origin.x += iconSize + GrowlBrushedIconTextPadding;

	if (haveTitle) {
		[titleLayoutManager drawGlyphsForGlyphRange:titleRange atPoint:drawRect.origin];
		drawRect.origin.y += titleHeight + GrowlBrushedTitleTextPadding;
	}

	if (haveText) {
		[textLayoutManager drawGlyphsForGlyphRange:textRange atPoint:drawRect.origin];
	}

	[window invalidateShadow];
}

- (void) setIcon:(NSImage *)anIcon {
	[icon release];
	icon = [anIcon retain];
	[self sizeToFit];
	[self setNeedsDisplay:YES];
}

- (void) setTitle:(NSString *)aTitle {
	haveTitle = [aTitle length] != 0;

	if (!haveTitle) {
		[self sizeToFit];
		[self setNeedsDisplay:YES];
		return;
	}

	if (!titleStorage) {
		NSSize containerSize;
		containerSize.width = GrowlBrushedTextAreaWidth;
		containerSize.height = FLT_MAX;
		titleStorage = [[NSTextStorage alloc] init];
		titleContainer = [[NSTextContainer alloc] initWithContainerSize:containerSize];
		[titleLayoutManager addTextContainer:titleContainer];	// retains textContainer
		[titleContainer release];
		[titleStorage addLayoutManager:titleLayoutManager];	// retains layoutManager
		[titleContainer setLineFragmentPadding:0.0f];
	}

	// construct attributes for the title
	NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSFont *titleFont = [NSFont boldSystemFontOfSize:GrowlBrushedTitleFontSize];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		titleFont,      NSFontAttributeName,
		textColor,      NSForegroundColorAttributeName,
		textShadow,     NSShadowAttributeName,
		paragraphStyle, NSParagraphStyleAttributeName,
		nil];
	[paragraphStyle release];

	[[titleStorage mutableString] setString:aTitle];
	[titleStorage setAttributes:attributes range:NSMakeRange(0, [titleStorage length])];

	[attributes release];

	titleRange = [titleLayoutManager glyphRangeForTextContainer:titleContainer];	// force layout
	titleHeight = [titleLayoutManager usedRectForTextContainer:titleContainer].size.height;

	[self sizeToFit];
	[self setNeedsDisplay:YES];
}

- (void) setText:(NSString *)aText {
	haveText = [aText length] != 0;

	if (!haveText) {
		[self sizeToFit];
		[self setNeedsDisplay:YES];
		return;
	}

	if (!textStorage) {
		NSSize containerSize;
		BOOL limitPref = GrowlBrushedLimitPrefDefault;
		READ_GROWL_PREF_BOOL(GrowlBrushedLimitPref, GrowlBrushedPrefDomain, &limitPref);
		containerSize.width = GrowlBrushedTextAreaWidth;
		if (limitPref) {
			containerSize.height = lineHeight * GrowlBrushedMaxLines;
		} else {
			containerSize.height = FLT_MAX;
		}
		textStorage = [[NSTextStorage alloc] init];
		textContainer = [[NSTextContainer alloc] initWithContainerSize:containerSize];
		[textLayoutManager addTextContainer:textContainer];	// retains textContainer
		[textContainer release];
		[textStorage addLayoutManager:textLayoutManager];	// retains layoutManager
		[textContainer setLineFragmentPadding:0.0f];
	}

	// construct attributes for the description text
	NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		textFont,   NSFontAttributeName,
		textColor,  NSForegroundColorAttributeName,
		textShadow, NSShadowAttributeName,
		nil];

	[[textStorage mutableString] setString:aText];
	[textStorage setAttributes:attributes range:NSMakeRange(0, [textStorage length])];

	[attributes release];

	textRange = [textLayoutManager glyphRangeForTextContainer:textContainer];	// force layout
	textHeight = [textLayoutManager usedRectForTextContainer:textContainer].size.height;

	[self sizeToFit];
	[self setNeedsDisplay:YES];
}

- (void) setPriority:(int)priority {
	NSString *textKey;
	switch (priority) {
		case -2:
			textKey = GrowlBrushedVeryLowTextColor;
			break;
		case -1:
			textKey = GrowlBrushedModerateTextColor;
			break;
		case 1:
			textKey = GrowlBrushedHighTextColor;
			break;
		case 2:
			textKey = GrowlBrushedEmergencyTextColor;
			break;
		case 0:
		default:
			textKey = GrowlBrushedNormalTextColor;
			break;
	}
	NSData *data = nil;

	[textColor release];
	READ_GROWL_PREF_VALUE(textKey, GrowlBrushedPrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:[NSData class]]) {
		textColor = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		textColor = [NSColor colorWithCalibratedWhite:0.1f alpha:1.0f];
	}
	[textColor retain];
	[data release];
}

- (void) sizeToFit {
	NSRect rect = [self frame];
	rect.size.height = GrowlBrushedPadding + GrowlBrushedPadding + [self titleHeight] + [self descriptionHeight];
	if (haveTitle && haveText) {
		rect.size.height += GrowlBrushedTitleTextPadding;
	}
	if (rect.size.height < GrowlBrushedMinTextHeight) {
		rect.size.height = GrowlBrushedMinTextHeight;
	}
	[self setFrame:rect];

	// resize the window so that it contains the tracking rect
	NSRect windowRect = [[self window] frame];
	windowRect.size = rect.size;
	[[self window] setFrame:windowRect display:NO];

	if (trackingRectTag) {
		[self removeTrackingRect:trackingRectTag];
	}
	trackingRectTag = [self addTrackingRect:rect owner:self userData:NULL assumeInside:NO];
}

- (float) titleHeight {
	return haveTitle ? titleHeight : 0.0f;
}

- (float) descriptionHeight {
	return haveText ? textHeight : 0.0f;
}

- (int) descriptionRowCount {
	int rowCount = textHeight / lineHeight;
	BOOL limitPref = GrowlBrushedLimitPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlBrushedLimitPref, GrowlBrushedPrefDomain, &limitPref);
	if (limitPref) {
		return MIN(rowCount, GrowlBrushedMaxLines);
	} else {
		return rowCount;
	}
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

#pragma mark -

- (BOOL) mouseOver {
	return mouseOver;
}

- (void) setCloseOnMouseExit:(BOOL)flag {
	closeOnMouseExit = flag;
}

- (BOOL) acceptsFirstMouse:(NSEvent *) theEvent {
#pragma unused(theEvent)
	return YES;
}

- (void) mouseEntered:(NSEvent *)theEvent {
#pragma unused(theEvent)
	mouseOver = YES;
	[self setNeedsDisplay:YES];
}

- (void) mouseExited:(NSEvent *)theEvent {
#pragma unused(theEvent)
	mouseOver = NO;
	[self setNeedsDisplay:YES];

	// abuse the target object
	if (closeOnMouseExit && [target respondsToSelector:@selector(startFadeOut)]) {
		[target performSelector:@selector(startFadeOut)];
	}
}

- (void) mouseDown:(NSEvent *) event {
#pragma unused(event)
	mouseOver = NO;
	if (target && action && [target respondsToSelector:action]) {
		[target performSelector:action withObject:self];
	}
}

@end
