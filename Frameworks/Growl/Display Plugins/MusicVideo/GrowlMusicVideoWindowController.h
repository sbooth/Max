//
//  GrowlMusicVideoWindowController.h
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 09/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "FadingWindowController.h"

@class GrowlMusicVideoWindowView;

@interface GrowlMusicVideoWindowController : FadingWindowController {
	float						frameHeight;
	int							priority;
	NSView						*contentView;
	GrowlMusicVideoWindowView	*subview;
	NSPoint						frameOrigin;
	NSString					*identifier;
}

- (id) initWithTitle:(NSString *)title text:(NSString *)text icon:(NSImage *)icon priority:(int)priority identifier:(NSString *)ident;

- (NSString *) identifier;
- (int) priority;
- (void) setPriority:(int)newPriority;
- (void) setTitle:(NSString *)title;
- (void) setText:(NSString *)text;
- (void) setIcon:(NSImage *)icon;
	
@end
