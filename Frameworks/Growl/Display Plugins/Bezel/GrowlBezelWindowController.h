//
//  GrowlBezelWindowController.h
//  Display Plugins
//
//  Created by Jorge Salvador Caffarena on 09/09/04.
//  Copyright 2004 Jorge Salvador Caffarena. All rights reserved.
//

#import "FadingWindowController.h"

@class GrowlBezelWindowView;

@interface GrowlBezelWindowController : FadingWindowController {
	int						priority;
	double					scaleFactor;
	BOOL					flipIn;
	BOOL					flipOut;
	BOOL					shrinkEnabled;
	NSString				*identifier;
	GrowlBezelWindowView	*contentView;
}

- (id) initWithTitle:(NSString *)title text:(NSString *)text icon:(NSImage *)icon priority:(int)priority identifier:(NSString *)ident;

- (NSString *) identifier;
- (int) priority;
- (void) setPriority:(int)newPriority;
- (void) setTitle:(NSString *)title;
- (void) setText:(NSString *)text;
- (void) setIcon:(NSImage *)icon;

- (void) _fadeIn:(NSTimer *)timer;
- (void) _fadeOut:(NSTimer *)timer;

- (void) setFlipIn:(BOOL)flag;
- (void) setFlipOut:(BOOL)flag;

@end
