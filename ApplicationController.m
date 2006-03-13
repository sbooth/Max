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
#import "BOOLToStringValueTransformer.h"

static ApplicationController *sharedController = nil;

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

	transformer = [[[BOOLToStringValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BOOLToStringValueTransformer"];
	
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ApplicationControllerDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"ApplicationControllerDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

+ (ApplicationController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController) {
			sharedController = [[self alloc] init];
		}
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            return [super allocWithZone:zone];
        }
    }
    return sharedController;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (id) init
{
	if((self = [super init])) {		

		// Allowable file types
		_allowedTypes = [NSMutableArray arrayWithArray:getCoreAudioExtensions()];
		[(NSMutableArray *)_allowedTypes addObjectsFromArray:getLibsndfileExtensions()];
		[(NSMutableArray *)_allowedTypes addObjectsFromArray:getBuiltinExtensions()];

		[_allowedTypes retain];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_allowedTypes release];
	[super dealloc];
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
	if([[RipperController sharedController] hasTasks] || [[ConverterController sharedController] hasTasks] || [[EncoderController sharedController] hasTasks]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"Really Quit?", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"There are active ripping/encoding tasks", @"General", @"")];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return NSTerminateCancel;
		}
		// Remove all tasks
		else {
			[[RipperController sharedController] stopAllTasks:self];
			[[ConverterController sharedController] stopAllTasks:self];
			[[EncoderController sharedController] stopAllTasks:self];
		}
	}
	
	return NSTerminateNow;
}

/*- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSError *error;
	
	if(nil == [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filename] display:YES error:&error]) {
		[self encodeFiles:[NSArray arrayWithObject:filename]];
	}		
	
	return YES;
}*/

- (IBAction) encodeFile:(id)sender
{
	NSOpenPanel			*panel			= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
		
	if(NSOKButton == [panel runModalForTypes:_allowedTypes]) {

		@try {
			[self encodeFiles:[panel filenames]];
		}
		
		@catch(NSException *exception) {
			displayExceptionAlert(exception);
		}		
	}
}

- (void) encodeFiles:(NSArray *)filenames
{
	NSFileManager		*manager		= [NSFileManager defaultManager];
	NSString			*filename;
	NSArray				*subpaths;
	BOOL				isDir;
	AudioMetadata		*metadata;
	NSEnumerator		*enumerator;
	NSString			*subpath;
	NSString			*composedPath;
	unsigned			i;
	
	for(i = 0; i < [filenames count]; ++i) {
		filename = [filenames objectAtIndex:i];
		
		if([manager fileExistsAtPath:filename isDirectory:&isDir]) {
			if(isDir) {
				subpaths	= [manager subpathsAtPath:filename];
				enumerator	= [subpaths objectEnumerator];
				
				while((subpath = [enumerator nextObject])) {
					composedPath = [NSString stringWithFormat:@"%@/%@", filename, subpath];
					
					// Ignore dotfiles
					if([[subpath lastPathComponent] hasPrefix:@"."]) {
						continue;
					}
					// Ignore files that don't have our extensions
					else if(NO == [_allowedTypes containsObject:[subpath pathExtension]]) {
						continue;
					}
					
					// Ignore directories
					if([manager fileExistsAtPath:composedPath isDirectory:&isDir] && NO == isDir) {
						metadata = [AudioMetadata metadataFromFile:composedPath];
						
						@try {
							[[ConverterController sharedController] convertFile:composedPath metadata:metadata];
						}
						
						@catch(FileFormatNotSupportedException *exception) {
							// Just let it go since we are traversing a folder
						}
					}
				}
			}
			else {
				metadata = [AudioMetadata metadataFromFile:filename];						
				[[ConverterController sharedController] convertFile:filename metadata:metadata];
			}
		}
		else {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"File not found", @"Exceptions", @"") userInfo:[NSDictionary dictionaryWithObject:filename forKey:@"filename"]];
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
