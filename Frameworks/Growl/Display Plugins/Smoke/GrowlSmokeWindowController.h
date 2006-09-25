//
//  GrowlSmokeWindowController.h
//  Display Plugins
//
//  Created by Matthew Walton on 11/09/2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//

#import "FadingWindowController.h"

@interface GrowlSmokeWindowController : FadingWindowController {
	unsigned	depth;
	NSString	*identifier;
	unsigned	uid;
	id			plugin; // the GrowlSmokeDisplay object which created us
}

- (id) initWithTitle:(NSString *) title text:(NSString *) text icon:(NSImage *) icon priority:(int) priority sticky:(BOOL) sticky depth:(unsigned)depth identifier:(NSString *)ident;
- (unsigned) depth;
@end
