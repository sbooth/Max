//
//  GrowlSmokeWindowView.m
//  Display Plugins
//
//  Created by Matthew Walton on 11/09/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "GrowlSmokeWindowView.h"
#import "GrowlSmokeDefines.h"
#import "GrowlDefinesInternal.h"
#import "GrowlImageAdditions.h"
#import "GrowlBezierPathAdditions.h"

#define GrowlSmokeTextAreaWidth (GrowlSmokeNotificationWidth - GrowlSmokePadding - iconSize - GrowlSmokeIconTextPadding - GrowlSmokePadding)
#define GrowlSmokeMinTextHeight	(GrowlSmokePadding + iconSize + GrowlSmokePadding)

@implementation GrowlSmokeWindowView

- (id) initWithFrame:(NSRect) frame {
	if ((self = [super initWithFrame:frame])) {
		textFont = [[NSFont systemFontOfSize:GrowlSmokeTextFontSize] retain];
		textLayoutManager = [[NSLayoutManager alloc] init];
		titleLayoutManager = [[NSLayoutManager alloc] init];
		lineHeight = [textLayoutManager defaultLineHeightForFont:textFont];
		textShadow = [[NSShadow alloc] init];
		[textShadow setShadowOffset:NSMakeSize(0.0f, -2.0f)];
		[textShadow setShadowBlurRadius:3.0f];

		int size = GrowlSmokeSizePrefDefault;
		READ_GROWL_PREF_INT(GrowlSmokeSizePref, GrowlSmokePrefDomain, &size);
		if (size == GrowlSmokeSizeLarge) {
			iconSize = GrowlSmokeIconSizeLarge;
		} else {
			iconSize = GrowlSmokeIconSize;
		}
	}

	return self;
}

- (void) dealloc {
	[textFont           release];
	[icon               release];
	[bgColor            release];
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

	// calculate bounds based on icon-float pref on or off
	NSRect shadedBounds;
	BOOL floatIcon = GrowlSmokeFloatIconPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlSmokeFloatIconPref, GrowlSmokePrefDomain, &floatIcon);
	if (floatIcon) {
		float sizeReduction = GrowlSmokePadding + iconSize + (GrowlSmokeIconTextPadding * 0.5f);

		shadedBounds = NSMakeRect(bounds.origin.x + sizeReduction,
								  bounds.origin.y,
								  bounds.size.width - sizeReduction,
								  bounds.size.height);
	} else {
		shadedBounds = bounds;
	}

	// set up bezier path for rounded corners
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(shadedBounds, 1.0f, 1.0f)
														  radius:GrowlSmokeBorderRadius];
	[path setLineWidth:2.0f];

	NSGraphicsContext *graphicsContext = [NSGraphicsContext currentContext];
	[graphicsContext saveGraphicsState];

	// clip graphics context to path
	[path setClip];

	// fill clipped graphics context with our background colour
	[bgColor set];
	NSRectFill(bounds);

	// revert to unclipped graphics context
	[graphicsContext restoreGraphicsState];

	if (mouseOver) {
		NSColor *borderColor = textColor;
		[borderColor set];
		[path stroke];
	}

	// draw the title and the text
	NSRect drawRect;
	drawRect.origin.x = GrowlSmokePadding;
	drawRect.origin.y = GrowlSmokePadding;
	drawRect.size.width = iconSize;
	drawRect.size.height = iconSize;

	[icon setFlipped:YES];
	[icon drawScaledInRect:drawRect
				 operation:NSCompositeSourceOver
				  fraction:1.0f];

	drawRect.origin.x += iconSize + GrowlSmokeIconTextPadding;

	if (haveTitle) {
		[titleLayoutManager drawGlyphsForGlyphRange:titleRange atPoint:drawRect.origin];
		drawRect.origin.y += titleHeight + GrowlSmokeTitleTextPadding;
	}

	if (haveText) {
		[textLayoutManager drawGlyphsForGlyphRange:textRange atPoint:drawRect.origin];
	}

	[[self window] invalidateShadow];
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
		containerSize.width = GrowlSmokeTextAreaWidth;
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
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	NSFont *titleFont = [NSFont boldSystemFontOfSize:GrowlSmokeTitleFontSize];
	NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		titleFont,      NSFontAttributeName,
		textColor,		NSForegroundColorAttributeName,
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
		BOOL limitPref = GrowlSmokeLimitPrefDefault;
		READ_GROWL_PREF_BOOL(GrowlSmokeLimitPref, GrowlSmokePrefDomain, &limitPref);
		containerSize.width = GrowlSmokeTextAreaWidth;
		if (limitPref) {
			containerSize.height = lineHeight * GrowlSmokeMaxLines;
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
	NSString *key;
	NSString *textKey;
	switch (priority) {
		case -2:
			key = GrowlSmokeVeryLowColor;
			textKey = GrowlSmokeVeryLowTextColor;
			break;
		case -1:
			key = GrowlSmokeModerateColor;
			textKey = GrowlSmokeModerateTextColor;
			break;
		case 1:
			key = GrowlSmokeHighColor;
			textKey = GrowlSmokeHighTextColor;
			break;
		case 2:
			key = GrowlSmokeEmergencyColor;
			textKey = GrowlSmokeEmergencyTextColor;
			break;
		case 0:
		default:
			key = GrowlSmokeNormalColor;
			textKey = GrowlSmokeNormalTextColor;
			break;
	}

	float backgroundAlpha = GrowlSmokeAlphaPrefDefault;
	READ_GROWL_PREF_FLOAT(GrowlSmokeAlphaPref, GrowlSmokePrefDomain, &backgroundAlpha);
	backgroundAlpha *= 0.01f;

	[bgColor release];

	Class NSDataClass = [NSData class];
	NSData *data = nil;

	READ_GROWL_PREF_VALUE(key, GrowlSmokePrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:NSDataClass]) {
		bgColor = [NSUnarchiver unarchiveObjectWithData:data];
		bgColor = [bgColor colorWithAlphaComponent:backgroundAlpha];
	} else {
		bgColor = [NSColor colorWithCalibratedWhite:0.1f alpha:backgroundAlpha];
	}
	[bgColor retain];
	[data release];
	data = nil;

	[textColor release];
	READ_GROWL_PREF_VALUE(textKey, GrowlSmokePrefDomain, NSData *, &data);
	if (data && [data isKindOfClass:NSDataClass]) {
		textColor = [NSUnarchiver unarchiveObjectWithData:data];
	} else {
		textColor = [NSColor whiteColor];
	}
	[textColor retain];
	[data release];

	[textShadow setShadowColor:[bgColor blendedColorWithFraction:0.5f ofColor:[NSColor blackColor]]];
}

- (void) sizeToFit {
	NSRect rect = [self frame];
	rect.size.height = GrowlSmokePadding + GrowlSmokePadding + [self titleHeight] + [self descriptionHeight];
	if (haveTitle && haveText) {
		rect.size.height += GrowlSmokeTitleTextPadding;
	}
	if (rect.size.height < GrowlSmokeMinTextHeight) {
		rect.size.height = GrowlSmokeMinTextHeight;
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
	BOOL limitPref = GrowlSmokeLimitPrefDefault;
	READ_GROWL_PREF_BOOL(GrowlSmokeLimitPref, GrowlSmokePrefDomain, &limitPref);
	if (limitPref) {
		return MIN(rowCount, GrowlSmokeMaxLines);
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
