//
//  GrowlBrushedWindowView.h
//  Display Plugins
//
//  Created by Ingmar Stein on 12/01/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GrowlBrushedWindowView : NSView {
	BOOL				mouseOver;
	BOOL				haveTitle;
	BOOL				haveText;
	BOOL				closeOnMouseExit;
	NSImage				*icon;
	float				iconSize;
	float				textHeight;
	float				titleHeight;
	float				lineHeight;
	SEL					action;
	id					target;
	NSTrackingRectTag	trackingRectTag;

	NSFont				*textFont;
	NSShadow			*textShadow;
	NSColor				*textColor;

	NSLayoutManager		*textLayoutManager;
	NSTextStorage		*textStorage;
	NSTextContainer		*textContainer;
	NSRange				textRange;

	NSLayoutManager		*titleLayoutManager;
	NSTextStorage		*titleStorage;
	NSTextContainer		*titleContainer;
	NSRange				titleRange;
}

- (void) setIcon:(NSImage *)icon;
- (void) setTitle:(NSString *)title;
- (void) setText:(NSString *)text;

- (void) setPriority:(int)priority;

- (void) sizeToFit;
- (float) titleHeight;
- (float) descriptionHeight;
- (int) descriptionRowCount;

- (id) target;
- (void) setTarget:(id)object;

- (SEL) action;
- (void) setAction:(SEL)selector;

- (BOOL) mouseOver;
- (void) setCloseOnMouseExit:(BOOL)flag;
@end
