//
//  GrowlBubblesWindowController.h
//  Growl
//
//  Created by Nelson Elhage on Wed Jun 09 2004.
//  Name changed from KABubbleWindowController.h by Justin Burns on Fri Nov 05 2004.
//  Copyright (c) 2004 Nelson Elhage. All rights reserved.
//

#import "FadingWindowController.h"

@interface GrowlBubblesWindowController : FadingWindowController {
	unsigned	depth;
	NSString	*identifier;
}

- (id) initWithTitle:(NSString *) title text:(NSString *) text icon:(NSImage *) icon priority:(int)priority sticky:(BOOL)sticky identifier:(NSString *)identifier;

@end
