/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "ApplicationController.h"

#import "PreferencesController.h"
#import "MediaController.h"
#import "StringValueTransformer.h"
#import "CDDBProtocolValueTransformer.h";

#include "lame/lame.h"

@implementation ApplicationController

+ (void)initialize
{
	// Set up the ValueTransformers
	NSValueTransformer			*transformer;
	
	transformer = [[[StringValueTransformer alloc] initWithTarget:@"Bitrate"] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"LAMETargetIsBitrate"];
	
	transformer = [[[StringValueTransformer alloc] initWithTarget:@"Quality"] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"LAMETargetIsQuality"];
	
	transformer = [[[CDDBProtocolValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"CDDBProtocolValueTransformer"];
}

- (IBAction)showPreferences:(id)sender
{
	[[PreferencesController sharedPreferences] showPreferencesWindow];
}

- (IBAction)scanForMedia:(id)sender
{
	[[MediaController sharedMedia] scanForMedia];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[MediaController sharedMedia] scanForMedia];
}

- (IBAction)aboutLAME:(id)sender
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle: @"OK"];
	[alert setMessageText: @"About LAME"];
	[alert setInformativeText: [NSString stringWithFormat:@"LAME %s", get_lame_version()]];
	[alert setAlertStyle: NSWarningAlertStyle];
	
	if([alert runModal] == NSAlertFirstButtonReturn) {
		// do nothing
	} 
}

@end
