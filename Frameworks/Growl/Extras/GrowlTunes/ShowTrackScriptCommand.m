//
//  GrowlNotifyScriptCommand.m
//  Growl
//
//  Created by Patrick Linskey on Tue Aug 10 2004.
//  Copyright (c) 2005 The Growl Project. All rights reserved.
//

#import "ShowTrackScriptCommand.h"
#import "GrowlTunesController.h"

@implementation ShowTrackScriptCommand

- (id) performDefaultImplementation {
	[[GrowlTunesController sharedController] showCurrentTrack];

	return nil;
}

@end
