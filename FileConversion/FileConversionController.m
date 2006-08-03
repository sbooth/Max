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

#import "FileConversionController.h"
#import "ConverterController.h"
#import "PreferencesController.h"
#import "Genres.h"
#import "UtilityFunctions.h"
#import "IOException.h"
#import "MissingResourceException.h"

enum {
	kAlbumTitleMenuItem				= 1,
	kAlbumArtistMenuItem			= 2,
	kAlbumYearMenuItem				= 3,
	kAlbumGenreMenuItem				= 4,
	kAlbumComposerMenuItem			= 5,
	kTrackTitleMenuItem				= 6,
	kTrackArtistMenuItem			= 7,
	kTrackYearMenuItem				= 8,
	kTrackGenreMenuItem				= 9,
	kTrackComposerMenuItem			= 10,
	kTrackNumberMenuItemTag			= 11,
	kTrackTotalMenuItemTag			= 12,
	kFileFormatMenuItemTag			= 13,
	kDiscNumberMenuItemTag			= 14,
	kDiscTotalMenuItemTag			= 15
};

static FileConversionController *sharedController = nil;

@interface FileConversionController (Private)
- (void)	updateOutputDirectoryMenuItemImage;
- (void)	selectOutputDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (BOOL)	addOneFile:(NSString *)filename atIndex:(unsigned)index;
- (void)	clearFileList;
- (void)	selectTemporaryDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	updateTemporaryDirectoryMenuItemImage;
@end

@implementation FileConversionController

+ (void) initialize
{
	NSString				*defaultsValuesPath;
    NSDictionary			*defaultsValuesDictionary;
	
	@try {
		// Set up defaults
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"FileConversionDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"FileConversionDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];		
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"FileConversionController"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

+ (FileConversionController *) sharedController
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
	if((self = [super initWithWindowNibName:@"FileConversion"])) {
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_outputDirectory release];
	[_fileNamingFormat release];
	[super dealloc];
}

- (void) awakeFromNib
{
	NSArray		*patterns	= nil;
	
	// Pull in defaults
	_outputDirectory	= [[[[NSUserDefaults standardUserDefaults] stringForKey:@"conversionOutputDirectory"] stringByExpandingTildeInPath] retain];

	// Set the menu item images
	[self updateOutputDirectoryMenuItemImage];
	[self updateTemporaryDirectoryMenuItemImage];
	
	// Select the correct items
	[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
	[_temporaryDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomTemporaryDirectory"] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
	[_encodersController setSelectedObjects:getDefaultOutputFormats()];
	
	// Deselect all items in the File Format Specifier NSPopUpButton
	[[_formatSpecifierPopUpButton selectedItem] setState:NSOffState];
	[_formatSpecifierPopUpButton selectItemAtIndex:-1];
	[_formatSpecifierPopUpButton synchronizeTitleAndSelectedItem];

	// Set the value to the most recently-saved pattern
	patterns = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"conversionFileNamingPatterns"];
	if(0 < [patterns count]) {
		[_fileNamingComboBox setStringValue:[patterns objectAtIndex:0]];
	}	
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"FileConversion"];
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
	AudioMetadata		*metadata				= nil;
	NSArray				*filenames				= nil;
	NSString			*outputDirectory		= nil;
	NSString			*filename				= nil;
	NSMutableDictionary	*userInfo				= nil;
	int					deleteSourceFilesTag	= 0;
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
	
	[userInfo setObject:[NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"conversionOverwriteExistingFiles"]] forKey:@"overwriteExistingFiles"];
	
	deleteSourceFilesTag = [[NSUserDefaults standardUserDefaults] boolForKey:@"conversionDeleteSourceFiles"];
	if(kOverwriteExistingFiles == deleteSourceFilesTag) {
		[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"deleteSourceFiles"];
	}
	else {
		[userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"deleteSourceFiles"];
	}
	
	// Iterate through file list and convert each one
	filenames = [_filesController arrangedObjects];
	for(i = 0; i < [filenames count]; ++i) {

		filename	= [[filenames objectAtIndex:i] objectForKey:@"filename"];
		metadata	= [[filenames objectAtIndex:i] objectForKey:@"metadata"];
		
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

- (IBAction) insertFileNamingFormatSpecifier:(id)sender
{
	NSString		*string;
	NSText			*fieldEditor;
	
	switch([[sender selectedItem] tag]) {
		case kAlbumTitleMenuItem:			string = @"{albumTitle}";		break;
		case kAlbumArtistMenuItem:			string = @"{albumArtist}";		break;
		case kAlbumYearMenuItem:			string = @"{albumYear}";		break;
		case kAlbumGenreMenuItem:			string = @"{albumGenre}";		break;
		case kAlbumComposerMenuItem:		string = @"{albumComposer}";	break;
		case kTrackTitleMenuItem:			string = @"{trackTitle}";		break;
		case kTrackArtistMenuItem:			string = @"{trackArtist}";		break;
		case kTrackYearMenuItem:			string = @"{trackYear}";		break;
		case kTrackGenreMenuItem:			string = @"{trackGenre}";		break;
		case kTrackComposerMenuItem:		string = @"{trackComposer}";	break;
		case kTrackNumberMenuItemTag:		string = @"{trackNumber}";		break;
		case kTrackTotalMenuItemTag:		string = @"{trackTotal}";		break;
		case kFileFormatMenuItemTag:		string = @"{fileFormat}";		break;
		case kDiscNumberMenuItemTag:		string = @"{discNumber}";		break;
		case kDiscTotalMenuItemTag:			string = @"{discTotal}";		break;
		default:							string = @"";					break;
	}
	
	fieldEditor = [_fileNamingComboBox currentEditor];
	if(nil == fieldEditor) {
		[_fileNamingComboBox setStringValue:string];
	}
	else {
		if([_fileNamingComboBox textShouldBeginEditing:fieldEditor]) {
			[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
			[_fileNamingComboBox textShouldEndEditing:fieldEditor];
		}
	}
}

- (IBAction) saveFileNamingFormat:(id)sender
{
	NSString		*pattern	= [_fileNamingComboBox stringValue];
	NSMutableArray	*patterns	= nil;
	
	patterns = [[[[NSUserDefaults standardUserDefaults] arrayForKey:@"conversionFileNamingPatterns"] mutableCopy] autorelease];
	if(nil == patterns) {
		patterns = [NSMutableArray array];
	}
	
	if([patterns containsObject:pattern]) {
		[patterns removeObject:pattern];
	}	

	[patterns insertObject:pattern atIndex:0];

	while(10 < [patterns count]) {
		[patterns removeLastObject];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:patterns forKey:@"conversionFileNamingPatterns"];	
}

- (IBAction) selectTemporaryDirectory:(id)sender
{
	NSOpenPanel *panel = nil;
	
	switch([[sender selectedItem] tag]) {
		case kDefaultTempDirectoryMenuItemTag:
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"conversionUseCustomTemporaryDirectory"];
			break;
			
		case kCurrentTempDirectoryMenuItemTag:
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomTemporaryDirectory"]) {
				[[NSWorkspace sharedWorkspace] selectFile:[[NSUserDefaults standardUserDefaults] stringForKey:@"conversionTemporaryDirectory"] inFileViewerRootedAtPath:nil];
			}
			else {
				[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:@"conversionUseCustomTemporaryDirectory"]; 
			}
			break;
			
		case kChooseTempDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(selectTemporaryDirectoryDidEnd:returnCode:contextInfo:) contextInfo:nil];
			break;
	}
}

- (void) selectTemporaryDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
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
				[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:@"conversionUseCustomTemporaryDirectory"]; 
				[[NSUserDefaults standardUserDefaults] setValue:dirname forKey:@"conversionTemporaryDirectory"];
				[self updateTemporaryDirectoryMenuItemImage];
			}
				
				[_temporaryDirectoryPopUpButton selectItemWithTag:kCurrentTempDirectoryMenuItemTag];	
			break;
			
		case NSCancelButton:
			[_temporaryDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomTemporaryDirectory"] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
			break;
	}	
}

- (void) updateTemporaryDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [[NSUserDefaults standardUserDefaults] stringForKey:@"conversionTemporaryDirectory"];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_temporaryDirectoryPopUpButton itemAtIndex:[_temporaryDirectoryPopUpButton indexOfItemWithTag:kCurrentTempDirectoryMenuItemTag]];	
	
	[menuItem setTitle:[path lastPathComponent]];
	[menuItem setImage:image];
}

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
	NSImage				*icon			= nil;
	AudioMetadata		*metadata		= nil;

	// Don't re-add files
	if([_filesController containsFile:filename]) {
		return YES;
	}
	// Only accept files with our extensions
	else if(NO == [getAudioExtensions() containsObject:[filename pathExtension]]) {	
		return NO;
	}
	
	// Get file's metadata
	metadata = [AudioMetadata metadataFromFile:filename];
	
	// Get the icon for the file
	icon = getIconForFile(filename, NSMakeSize(16, 16));

	if(NSNotFound == index) {
		[_filesController addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [filename lastPathComponent], icon, metadata, nil] forKeys:[NSArray arrayWithObjects:@"filename", @"displayName", @"icon", @"metadata", nil]]];
	}
	else {
		[_filesController insertObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [filename lastPathComponent], icon, metadata, nil] forKeys:[NSArray arrayWithObjects:@"filename", @"displayName", @"icon", @"metadata", nil]] atArrangedObjectIndex:index];			
	}
	
	return YES;
}

#pragma mark Miscellaneous

- (NSArray *)				genres											{ return [Genres sharedGenres]; }

- (NSString *)				fileNamingFormat								{ return _fileNamingFormat; }
- (void)					setFileNamingFormat:(NSString *)fileNamingFormat { [_fileNamingFormat release]; _fileNamingFormat = [fileNamingFormat retain]; }

- (BOOL)					convertInPlace									{ return _convertInPlace; }
- (void)					setConvertInPlace:(BOOL)convertInPlace			{ _convertInPlace = convertInPlace; }

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
