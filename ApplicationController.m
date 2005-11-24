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
#import "TaskMaster.h"
#import "UpdateChecker.h"
#import "IOException.h"
#import "StringValueTransformer.h"
#import "FreeDBProtocolValueTransformer.h";
#import "BooleanArrayValueTransformer.h";
#import "NegateBooleanArrayValueTransformer.h";

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
	
	transformer = [[[FreeDBProtocolValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"FreeDBProtocolValueTransformer"];

	transformer = [[[BooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BooleanArrayValueTransformer"];

	transformer = [[[NegateBooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NegateBooleanArrayValueTransformer"];
}

-(void)awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (IBAction)showPreferences:(id)sender
{
	[[PreferencesController sharedPreferences] showWindow:self];
}

- (IBAction)scanForMedia:(id)sender
{
	[[MediaController sharedController] scanForMedia];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[MediaController sharedController] scanForMedia];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender
{
	if(0 != [[[TaskMaster sharedController] valueForKey:@"taskList"] count]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setMessageText:@"Really Quit?"];
		[alert setInformativeText:@"There are active ripping/encoding tasks."];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return NSTerminateCancel;
		}
		// Remove all tasks
		else {
			NSEnumerator *enumerator = [[[TaskMaster sharedController] valueForKey:@"taskList"] objectEnumerator];
			Task *task;
			
			while((task = [enumerator nextObject])) {
				[[TaskMaster sharedController] removeTask:task];
			}		
		}
	}
	
	[[MediaController sharedController] releaseAll];
	
	return NSTerminateNow;
}

- (IBAction)aboutLAME:(id)sender
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"About LAME"];
	[alert setInformativeText:[NSString stringWithFormat:@"LAME %s", get_lame_short_version()]];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	if([alert runModal] == NSAlertFirstButtonReturn) {
		// do nothing
	} 
}

- (IBAction)toggleTasksPanel:(id)sender
{
	NSWindow *tasksWindow = [[TaskMaster sharedController] window];
	if([tasksWindow isVisible]) {
		[tasksWindow performClose:self];
	}
	else {
		[tasksWindow orderFront:self];
	}
}

- (IBAction) checkForUpdate:(id)sender
{
	[[UpdateChecker sharedController] checkForUpdate];
}

- (IBAction)openHomeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sbooth.org/Max/"]];
}

-(NSDictionary *)registrationDictionaryForGrowl
{
	NSArray *defaultNotifications = [NSArray arrayWithObjects:
		@"Rip started",
		@"Rip completed",
		@"Rip stopped",
		@"Encode started",
		@"Encode completed",
		@"Encode stopped",
		nil
		];

	NSArray *allNotifications = [NSArray arrayWithObjects:
		@"Rip started",
		@"Rip completed",
		@"Rip stopped",
		@"Encode started",
		@"Encode completed",
		@"Encode stopped",
		nil
		];
	
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Max", GROWL_APP_NAME, 
		allNotifications, GROWL_NOTIFICATIONS_ALL, 
		defaultNotifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	return regDict;
}

@end
