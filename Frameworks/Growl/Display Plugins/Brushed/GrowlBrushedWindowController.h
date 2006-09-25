//
//  GrowlBrushedWindowController.h
//  Display Plugins
//
//  Created by Ingmar Stein on 12/01/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "FadingWindowController.h"

@interface GrowlBrushedWindowController : FadingWindowController {
	unsigned	depth;
	NSString	*identifier;
	unsigned	uid;
	id			plugin; // the GrowlBrushedDisplay object which created us
}

- (id) initWithTitle:(NSString *) title text:(NSString *) text icon:(NSImage *) icon priority:(int) priority sticky:(BOOL) sticky depth:(unsigned)depth identifier:(NSString *)ident;
- (unsigned) depth;
@end
