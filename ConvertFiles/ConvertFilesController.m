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

#import "ConvertFilesController.h"
#import "ConverterController.h"
#import "PreferencesController.h"
#import "UtilityFunctions.h"
#import "IOException.h"

static ConvertFilesController *sharedController = nil;

@interface ConvertFilesController (Private)
- (void)	updateOutputDirectoryMenuItemImage;
- (void)	selectOutputDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (BOOL)	addOneFile:(NSString *)filename atIndex:(unsigned)index;
- (void)	clearFileList;
@end

@implementation ConvertFilesController

+ (ConvertFilesController *) sharedController
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

- (id) init
{
	if((self = [super initWithWindowNibName:@"ConvertFiles"])) {
		
		_outputDirectory = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] retain];

		// Pull in defaults
		[self setDeleteSourceFiles:[[NSUserDefaults standardUserDefaults] boolForKey:@"deleteAfterConversion"]];

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_outputDirectory release];
	[super dealloc];
}

- (void) awakeFromNib
{
	// Set the menu item image
	[self updateOutputDirectoryMenuItemImage];
	
	// Select the correct item
	[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
	
	[_encodersController setSelectedObjects:getDefaultOutputFormats()];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"ConvertFiles"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

#pragma mark Action Methods

- (IBAction) ok:(id)sender
{
	AudioMetadata		*metadata			= nil;
	NSArray				*filenames			= nil;
	NSString			*outputDirectory	= nil;
	NSString			*filename			= nil;
	NSMutableDictionary	*userInfo			= nil;
	
	unsigned			i;

	// Verify at least one output format is selected
	if(0 == [[_encodersController arrangedObjects] count]) {
		int		result;
		
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"No output formats are selected.", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		result = [alert runModal];
		
		if(NSAlertFirstButtonReturn == result) {
			// do nothing
		}
		else if(NSAlertSecondButtonReturn == result) {
			[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
			[[PreferencesController sharedPreferences] showWindow:self];
		}
		
		return;
	}

	// Conversion parameters
	outputDirectory		= ([self convertInPlace] ? nil : _outputDirectory);
	userInfo			= [NSMutableDictionary dictionary];
	[userInfo setObject:[NSNumber numberWithBool:[self overwriteExistingFiles]] forKey:@"overwriteExistingFiles"];
	[userInfo setObject:[NSNumber numberWithBool:[self deleteSourceFiles]] forKey:@"deleteSourceFiles"];
	
	// Iterate through file list and convert each one
	filenames = [_filesController arrangedObjects];
	for(i = 0; i < [filenames count]; ++i) {

		filename	= [[filenames objectAtIndex:i] objectForKey:@"filename"];
		metadata	= [AudioMetadata metadataFromFile:filename];
		
		@try {
			[[ConverterController sharedController] convertFile:filename metadata:metadata withEncoders:[_encodersController selectedObjects] toDirectory:outputDirectory userInfo:userInfo];
		}
		
		@catch(NSException *exception) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while converting the file \"%@\".", @"Exceptions", @""), [filename lastPathComponent]]];
			[alert setInformativeText:[exception reason]];
			[alert setAlertStyle:NSWarningAlertStyle];		
			[alert runModal];
		}			
	}

	// Get ready for next time
//	[[self window] performClose:self];
	[self clearFileList];
}

- (IBAction) cancel:(id)sender
{
	[[self window] performClose:self];
	//[_filesController removeObjects:[_filesController arrangedObjects]];
}

- (IBAction) addFiles:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	[panel beginSheetForDirectory:nil file:nil types:getAudioExtensions() modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];	
}

- (void) openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray			*filenames;
	unsigned		i;

	if(NSOKButton == returnCode) {
		
		filenames = [panel filenames];

		for(i = 0; i < [filenames count]; ++i) {
			[self addFile:[filenames objectAtIndex:i]];
		}
	}
}

- (IBAction) removeFiles:(id)sender
{
	[_filesController removeObjects:[_filesController selectedObjects]];	
}

- (IBAction) selectOutputDirectory:(id)sender
{
	NSOpenPanel *panel = nil;
	
	switch([[sender selectedItem] tag]) {
		case kCurrentDirectoryMenuItemTag:
			[[NSWorkspace sharedWorkspace] selectFile:_outputDirectory inFileViewerRootedAtPath:nil];
			[self setConvertInPlace:NO];
			break;
			
		case kChooseDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(selectOutputDirectoryDidEnd:returnCode:contextInfo:) contextInfo:nil];
			break;
			
		case kSameAsSourceFileMenuItemTag:
			[self setConvertInPlace:YES];
			break;
	}
}

- (void) selectOutputDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray		*filesToOpen;
	NSString	*dirname;
	int			count, i;
	
	switch(returnCode) {
		
		case NSOKButton:
			filesToOpen		= [sheet filenames];
			count			= [filesToOpen count];
			
			for(i = 0; i < count; ++i) {
				dirname = [filesToOpen objectAtIndex:i];
				[_outputDirectory release];
				_outputDirectory = [[dirname stringByAbbreviatingWithTildeInPath] retain];
				[self updateOutputDirectoryMenuItemImage];
			}
				
				[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
			break;
			
		case NSCancelButton:
			[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
			break;
	}
}

/*- (IBAction) resetOutputDirectoryToDefault:(id)sender
{
	[_outputDirectory release];
	_outputDirectory = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] retain];	
	
	[self updateOutputDirectoryMenuItemImage];
	[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
}*/

#pragma mark File Management

- (BOOL) addFile:(NSString *)filename
{
	return [self addFile:filename atIndex:/*[[_filesController arrangedObjects] count]*/NSNotFound];
}

- (BOOL) addFile:(NSString *)filename atIndex:(unsigned)index
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	NSArray				*allowedTypes		= getAudioExtensions();
	NSMutableArray		*newFiles;
	NSDictionary		*file;
	NSArray				*subpaths;
	BOOL				isDir;
	NSEnumerator		*enumerator;
	NSString			*subpath;
	NSString			*composedPath;
	BOOL				success				= YES;
	
	if([manager fileExistsAtPath:filename isDirectory:&isDir]) {
		newFiles = [NSMutableArray arrayWithCapacity:10];
		
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
				else if(NO == [allowedTypes containsObject:[subpath pathExtension]]) {
					continue;
				}
				
				// Ignore directories
				if([manager fileExistsAtPath:composedPath isDirectory:&isDir] && NO == isDir) {
					success &= [self addOneFile:composedPath atIndex:(unsigned)index];
				}
				
				if(success) {
					file = [_filesController findFile:composedPath];
					if(nil != file) {
						[newFiles addObject:file];
					}
				}
			}
			
			if(success) {
				[_filesController setSelectedObjects:newFiles];
			}
		}
		else {
			success &= [self addOneFile:filename atIndex:(unsigned)index];
			if(success) {
				[_filesController selectFile:filename];
			}
		}
	}
	else {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @"") userInfo:nil];
	}
	
	return success;
}

- (BOOL) addOneFile:(NSString *)filename atIndex:(unsigned)index
{
	NSImage		*icon		= nil;

	// Don't re-add files
	if([_filesController containsFile:filename]) {
		return YES;
	}
	// Only accept files with our extensions
	else if(NO == [getAudioExtensions() containsObject:[filename pathExtension]]) {	
		return NO;
	}
	
	// Get the icon for the file
	icon = getIconForFile(filename, NSMakeSize(16, 16));

	if(NSNotFound == index) {
		[_filesController addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [filename lastPathComponent], icon, nil] forKeys:[NSArray arrayWithObjects:@"filename", @"displayName", @"icon", nil]]];
	}
	else {
		[_filesController insertObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [filename lastPathComponent], icon, nil] forKeys:[NSArray arrayWithObjects:@"filename", @"displayName", @"icon", nil]] atArrangedObjectIndex:index];			
	}
	
	return YES;
}

#pragma mark Miscellaneous

- (BOOL)					convertInPlace									{ return _convertInPlace; }
- (void)					setConvertInPlace:(BOOL)convertInPlace			{ _convertInPlace = convertInPlace; }

- (BOOL)					overwriteExistingFiles							{ return _overwriteExistingFiles; }
- (void)					setOverwriteExistingFiles:(BOOL)overwriteExistingFiles { _overwriteExistingFiles = overwriteExistingFiles; }

- (BOOL)					deleteSourceFiles								{ return _deleteSourceFiles; }
- (void)					setDeleteSourceFiles:(BOOL)deleteSourceFiles	{ _deleteSourceFiles = deleteSourceFiles; }

- (void) updateOutputDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [_outputDirectory stringByExpandingTildeInPath];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_outputDirectoryPopUpButton itemAtIndex:[_outputDirectoryPopUpButton indexOfItemWithTag:kCurrentDirectoryMenuItemTag]];	
	
	[menuItem setTitle:[path lastPathComponent]];
	[menuItem setImage:image];
}

- (void) clearFileList
{
	[_filesController removeObjects:[_filesController arrangedObjects]];
}

@end
