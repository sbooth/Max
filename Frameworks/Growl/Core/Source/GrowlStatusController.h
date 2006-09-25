//
//  GrowlStatusController.h
//  Growl
//
//  Created by Ingmar Stein on 17.06.05.
//  Copyright 2005 The Growl Project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GrowlStatusController : NSObject {
	BOOL	isIdle;
	double	lastSeenIdle;
	NSTimer	*idleTimer;
}

- (BOOL) isIdle;
- (void) setIdle:(BOOL)inIdle;
@end
