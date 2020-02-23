/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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
#import "FileConversionController.h"
#import "AcknowledgmentsController.h"
#import "ComponentVersionsController.h"
#import "MediaController.h"
#import "RipperController.h"
#import "EncoderController.h"
#import "LogController.h"
#import "FormatsController.h"
#import "FileFormatNotSupportedException.h"
#import "CoreAudioUtilities.h"
#import "UtilityFunctions.h"

#import "BooleanArrayValueTransformer.h"
#import "ImageDimensionsValueTransformer.h"
#import "NegateBooleanArrayValueTransformer.h"
#import "MultiplicationValueTransformer.h"
#import "BOOLToStringValueTransformer.h"
#import "UppercaseStringValueTransformer.h"

static ApplicationController *sharedController = nil;

@implementation ApplicationController

+ (void) initialize
{
	// Set up the ValueTransformers
	NSValueTransformer			*transformer;
	NSString					*defaultsValuesPath;
    NSDictionary				*defaultsValuesDictionary;
    

	transformer = [[[BooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BooleanArrayValueTransformer"];

	transformer = [[[ImageDimensionsValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"ImageDimensionsValueTransformer"];

	transformer = [[[NegateBooleanArrayValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"NegateBooleanArrayValueTransformer"];

	transformer = [[[MultiplicationValueTransformer alloc] initWithMultiplier:10] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"MultiplyByTenValueTransformer"];

	transformer = [[[BOOLToStringValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"BOOLToStringValueTransformer"];

	transformer = [[[UppercaseStringValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:transformer forName:@"UppercaseStringValueTransformer"];
			
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ApplicationControllerDefaults" ofType:@"plist"];
		NSAssert1(nil != defaultsValuesPath, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"ApplicationControllerDefaults.plist");

		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ApplicationController"]];
		[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ApplicationController"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

+ (ApplicationController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController)
			[[self alloc] init];
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            sharedController = [super allocWithZone:zone];
			return sharedController;
        }
    }
    return nil;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (NSUInteger)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void)	release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (BOOL)		applicationShouldOpenUntitledFile:(NSApplication *)sender	{ return NO; }

- (IBAction)	showPreferences:(id)sender									{ [[PreferencesController sharedPreferences] showWindow:sender]; }
- (IBAction)	showAcknowledgments:(id)sender								{ [[AcknowledgmentsController sharedController] showWindow:sender]; }
- (IBAction)	showComponentVersions:(id)sender							{ [[ComponentVersionsController sharedController] showWindow:sender]; }


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSArray		*openWindows	= nil;
	
	// Setup MediaController to receive DiskAppeared/DiskDisappeared callbacks
	[MediaController sharedController];
			
	// Register services
	[[NSApplication sharedApplication] setServicesProvider:[[ServicesProvider alloc] init]];
	
	// Show windows that were left open from last time
	openWindows = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"openWindows"];
	if(nil != openWindows) {
		if([openWindows containsObject:@"Ripper"]) {
			[[[RipperController sharedController] window] orderFront:self];
		}
		if([openWindows containsObject:@"Encoder"]) {
			[[[EncoderController sharedController] window] orderFront:self];
		}		
		if([openWindows containsObject:@"Log"]) {
			[[[LogController sharedController] window] orderFront:self];
		}
		if([openWindows containsObject:@"FileConversion"]) {
			[[[FileConversionController sharedController] window] orderFront:self];
		}
		if([openWindows containsObject:@"Formats"]) {
			[[[FormatsController sharedController] window] orderFront:self];
		}
	}
	
	// Log startup
	[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"Max successfully launched", @"Log", @"")];
}

- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *) sender
{
	NSMutableArray	*openWindows	= nil;
	
	if([[RipperController sharedController] hasTasks] || [[EncoderController sharedController] hasTasks]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"Do you want to quit while there are tasks in progress?", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"The resulting files will be lost if you quit now.", @"General", @"")];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return NSTerminateCancel;
		}
		// Remove all tasks
		else {
			[[RipperController sharedController] stopAllTasks:self];
			[[EncoderController sharedController] stopAllTasks:self];
		}
	}
	
	// Save open windows
	openWindows = [NSMutableArray array];
	if([[[RipperController sharedController] window] isVisible]) {
		[openWindows addObject:@"Ripper"];
	}
	if([[[EncoderController sharedController] window] isVisible]) {
		[openWindows addObject:@"Encoder"];
	}
	if([[[LogController sharedController] window] isVisible]) {
		[openWindows addObject:@"Log"];
	}
	if([[[FileConversionController sharedController] window] isVisible]) {
		[openWindows addObject:@"FileConversion"];
	}
	if([[[FormatsController sharedController] window] isVisible]) {
		[openWindows addObject:@"Formats"];
	}
	[[NSUserDefaults standardUserDefaults] setObject:openWindows forKey:@"openWindows"];

	return NSTerminateNow;
}

- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSDocument	*document;
	NSError		*error;
	
	// First try our document types
//	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filename] display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
//	}];
	document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filename] display:YES error:&error];
	
	if(nil != document)
		return YES;
	else if([GetAudioExtensions() containsObject:[[filename pathExtension] lowercaseString]]) {
		[self encodeFiles:[NSArray arrayWithObject:filename]];
		return YES;
	}		
	
	return NO;
}

- (IBAction) encodeFile:(id)sender
{
	[[FileConversionController sharedController] showWindow:self];
	[[FileConversionController sharedController] addFiles:self];
}

- (void) encodeFiles:(NSArray *)filenames
{
	[[FileConversionController sharedController] showWindow:self];

	for(NSString *filename in filenames)
		[[FileConversionController sharedController] addFile:filename];
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

- (IBAction) toggleFormatsWindow:(id)sender
{
	NSWindow *formatsWindow = [[FormatsController sharedController] window];
	if([formatsWindow isVisible])
		[formatsWindow performClose:self];
	else
		[formatsWindow makeKeyAndOrderFront:self];
}

- (IBAction) openHomeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sbooth.org/Max/"]];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	BOOL	result		= YES;
	
	if(@selector(encodeFile:) == [item action]) {
		result = ! [[[FileConversionController sharedController] window] isVisible];
	}
	
	return result;
}

@end

#pragma mark Scripting

@implementation NSApplication (ScriptingAdditions)

- (id) handleConvertScriptCommand:(NSScriptCommand *)command
{
	id			directParameter			= [command directParameter];
	Class		directParameterClass	= [directParameter class];
	
	@try {
		if([directParameterClass isEqual:[NSURL class]]) {
			NSURL	*url	= (NSURL *)directParameter;
			
			if([url isFileURL]) {
				[[ApplicationController sharedController] encodeFiles:[NSArray arrayWithObject:[url path]]];
			}
			
		}
		else if([directParameterClass isEqual:[NSArray class]]) {
			NSArray			*urlArray;
			NSURL			*url;
			NSMutableArray	*filenamesArray;
			
			urlArray		= (NSArray *)directParameter;
			filenamesArray	= [NSMutableArray arrayWithCapacity:[urlArray count]];
			
			for(url in urlArray) {
				if([url isFileURL]) {
					[filenamesArray addObject:[url path]];
				}
			}
			
			[[ApplicationController sharedController] encodeFiles:filenamesArray];
		}	
	}
	
	@catch(FileFormatNotSupportedException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		if(nil != [exception userInfo] && nil != [[exception userInfo] objectForKey:@"filename"]) {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
			[[LogController sharedController] logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the file \"%@\" for conversion.", @"Exceptions", @""), [[exception userInfo] objectForKey:@"filename"]]];
		}
		else {
			[alert setMessageText:NSLocalizedStringFromTable(@"An error occurred during file conversion.", @"Exceptions", @"")];
			[[LogController sharedController] logMessage:NSLocalizedStringFromTable(@"An error occurred during file conversion.", @"Exceptions", @"")];
		}
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}

	return nil;
}

@end
