/*
 *  $Id: ApplicationController.m 202 2005-12-04 21:50:52Z me $
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
#import "AcknowledgmentsController.h"
#import "ComponentVersionsController.h"
#import "MediaController.h"
#import "TaskMaster.h"
#import "RipperController.h"
#import "ConverterController.h"
#import "EncoderController.h"
#import "LogController.h"
#import "CoreAudioUtilities.h"
#import "UtilityFunctions.h"
#import "UpdateChecker.h"
#import "MacPADSocket.h"
#import "IOException.h"
#import "FreeDBProtocolValueTransformer.h"
#import "BooleanArrayValueTransformer.h"
#import "NegateBooleanArrayValueTransformer.h"

@implementation ApplicationController

+ (void)initialize
{
	// Set up the ValueTransformers
	NSValueTransformer			*transformer;
	
	transformer = [[[FreeDBProtocolValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"FreeDBProtocolValueTransformer"];

	transformer = [[[BooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BooleanArrayValueTransformer"];

	transformer = [[[NegateBooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NegateBooleanArrayValueTransformer"];
}

- (void) awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
	
	// Force the log window to load (so log messages will show up)
	[[LogController sharedController] window];
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (IBAction) showPreferences:(id)sender
{
	[[PreferencesController sharedPreferences] showWindow:self];
}

- (IBAction) showAcknowledgments:(id)sender
{
	[[AcknowledgmentsController sharedController] showWindow:self];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString		*bundleVersion;
	MacPADSocket	*macPAD;
		
	// Setup MediaController to receive DiskAppeared/DiskDisappeared callbacks
	[MediaController sharedController];
	
	// Check for new version
	bundleVersion	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	macPAD			= [[MacPADSocket alloc] init];

	[macPAD setDelegate:self];
	[macPAD performCheck:[NSURL URLWithString:@"http://sbooth.org/Max/Max.plist"] withVersion:bundleVersion];
	[[macPAD retain] autorelease];
}

- (void) macPADCheckFinished:(NSNotification *) aNotification
{
	if(kMacPADResultNewVersion == [[[aNotification userInfo] objectForKey:MacPADErrorCode] intValue]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: @"OK"];
		[alert setMessageText: @"Newer version available"];
		[alert setInformativeText: [NSString stringWithFormat:@"Max %@ is available.", [[aNotification object] newVersion]]];
		[alert setAlertStyle: NSInformationalAlertStyle];
		
		[alert runModal];
	}
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender
{
	if([[TaskMaster sharedController] hasTasks]) {
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
			[[TaskMaster sharedController] stopAllTasks:self];
		}
	}
	
	return NSTerminateNow;
}

- (IBAction) encodeFile:(id)sender
{
	NSOpenPanel		*panel			= [NSOpenPanel openPanel];

	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:NO];
	
	if(NSOKButton == [panel runModalForTypes:getCoreAudioExtensions()]) {
		NSArray			*filenames		= [panel filenames];
		unsigned		i;
		
		for(i = 0; i < [filenames count]; ++i) {
			NSString		*filename	= [filenames objectAtIndex:i];
			AudioMetadata	*metadata	= [[[AudioMetadata alloc] init] autorelease];
			NSString		*basename;
			
			// TODO: fill in metadata!

			basename = basenameForMetadata(metadata);
			createDirectoryStructure(basename);

			[[TaskMaster sharedController] encodeFile:filename outputBasename:basename metadata:metadata];
		}
	}
}

- (IBAction) showComponentVersions:(id)sender
{
	[[ComponentVersionsController sharedController] showWindow:self];
}

- (IBAction) toggleRipperWindow:(id)sender
{
	NSWindow *ripperWindow = [[RipperController sharedController] window];
	if([ripperWindow isVisible]) {
		[ripperWindow performClose:self];
	}
	else {
		[ripperWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) toggleConverterWindow:(id)sender
{
	NSWindow *converterWindow = [[ConverterController sharedController] window];
	if([converterWindow isVisible]) {
		[converterWindow performClose:self];
	}
	else {
		[converterWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) toggleEncoderWindow:(id)sender
{
	NSWindow *encoderWindow = [[EncoderController sharedController] window];
	if([encoderWindow isVisible]) {
		[encoderWindow performClose:self];
	}
	else {
		[encoderWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) toggleLogWindow:(id)sender
{
	NSWindow *logWindow = [[LogController sharedController] window];
	if([logWindow isVisible]) {
		[logWindow performClose:self];
	}
	else {
		[logWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction) checkForUpdate:(id)sender
{
	[[UpdateChecker sharedController] checkForUpdate];
}

- (IBAction) openHomeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sbooth.org/Max/"]];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *defaultNotifications = [NSArray arrayWithObjects:
		@"Rip started",
		@"Rip completed",
		@"Rip stopped",
		@"Convert started",
		@"Convert completed",
		@"Convert stopped",
		@"Encode started",
		@"Encode completed",
		@"Encode stopped",
		nil
		];

	NSArray *allNotifications = [NSArray arrayWithObjects:
		@"Rip started",
		@"Rip completed",
		@"Rip stopped",
		@"Convert started",
		@"Convert completed",
		@"Convert stopped",
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
