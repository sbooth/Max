/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
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

#import "ServicesProvider.h"
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
#import "MissingResourceException.h"
#import "FileFormatNotSupportedException.h"
#import "FreeDBProtocolValueTransformer.h"
#import "BooleanArrayValueTransformer.h"
#import "NegateBooleanArrayValueTransformer.h"
#import "MultiplicationValueTransformer.h"

@implementation ApplicationController

+ (void)initialize
{
	// Set up the ValueTransformers
	NSValueTransformer			*transformer;
	NSString					*defaultsValuesPath;
    NSDictionary				*defaultsValuesDictionary;
    
	
	transformer = [[[FreeDBProtocolValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"FreeDBProtocolValueTransformer"];

	transformer = [[[BooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BooleanArrayValueTransformer"];

	transformer = [[[NegateBooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NegateBooleanArrayValueTransformer"];

	transformer = [[[MultiplicationValueTransformer alloc] initWithMultiplier:10] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"MultiplyByTenValueTransformer"];
	
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ApplicationControllerDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to load '%@'", @"Exceptions", @""), @"ApplicationControllerDefaults.plist"] userInfo:nil];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}	
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
	// Setup MediaController to receive DiskAppeared/DiskDisappeared callbacks
	[MediaController sharedController];
		
	// Check for new version
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"startupVersionCheck"]) {
		[[UpdateChecker sharedController] checkForUpdate:NO];
	}
	
	// Register services
	[[NSApplication sharedApplication] setServicesProvider:[[ServicesProvider alloc] init]];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender
{
	if([[TaskMaster sharedController] hasTasks]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"Really Quit?", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"There are active ripping/encoding tasks.", @"General", @"")];
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
	NSOpenPanel			*panel			= [NSOpenPanel openPanel];
	NSMutableArray		*types;
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	// Allowable file types
	types = [NSMutableArray arrayWithArray:getCoreAudioExtensions()];
	[types addObjectsFromArray:getLibsndfileExtensions()];
	[types addObjectsFromArray:[NSArray arrayWithObjects:@"ogg", @"flac", @"oggflac", @"spx", nil]];
	
	if(NSOKButton == [panel runModalForTypes:types]) {
		NSFileManager		*manager		= [NSFileManager defaultManager];
		NSArray				*filenames		= [panel filenames];
		NSString			*filename;
		NSArray				*subpaths;
		BOOL				isDir;
		AudioMetadata		*metadata;
		NSString			*basename;
		NSEnumerator		*enumerator;
		NSString			*subpath;
		unsigned			i;
		
		for(i = 0; i < [filenames count]; ++i) {
			filename = [filenames objectAtIndex:i];
			
			if([manager fileExistsAtPath:filename isDirectory:&isDir]) {
				if(isDir) {
					subpaths	= [manager subpathsAtPath:filename];
					enumerator	= [subpaths objectEnumerator];
					
					while((subpath = [enumerator nextObject])) {
						metadata	= [AudioMetadata metadataFromFilename:[NSString stringWithFormat:@"%@/%@", filename, subpath]];
						basename	= [metadata outputBasename];
						
						createDirectoryStructure(basename);
						@try {
							[[TaskMaster sharedController] encodeFile:[NSString stringWithFormat:@"%@/%@", filename, subpath] outputBasename:basename metadata:metadata];
						}
						@catch(FileFormatNotSupportedException *exception) {
							// Just let it go since we are traversing a folder
						}
					}
				}
				else {
					metadata	= [AudioMetadata metadataFromFilename:filename];
					basename	= [metadata outputBasename];
					
					createDirectoryStructure(basename);
					
					@try {
						[[TaskMaster sharedController] encodeFile:filename outputBasename:basename metadata:metadata];
					}

					@catch(FileFormatNotSupportedException *exception) {
						displayExceptionAlert(exception);
					}
					
					@catch(NSException *exception) {
						@throw;
					}
					
				}
			}				
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
	[[UpdateChecker sharedController] checkForUpdate:YES];
}

- (IBAction) openHomeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sbooth.org/Max/"]];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *defaultNotifications = [NSArray arrayWithObjects:
		@"Rip stopped",
		@"Ripping completed",
		@"Convert stopped",
		@"Conversion completed",
		@"Encode stopped",
		@"Encoding completed",
		nil
		];

	NSArray *allNotifications = [NSArray arrayWithObjects:
		@"Rip started",
		@"Rip completed",
		@"Rip stopped",
		@"Ripping completed",
		@"Convert started",
		@"Convert completed",
		@"Convert stopped",
		@"Conversion completed",
		@"Encode started",
		@"Encode completed",
		@"Encode stopped",
		@"Encoding completed",
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
