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

#import "FileConversionController.h"
#import "FileConversionToolbar.h"
#import "FormatsController.h"
#import "EncoderController.h"
#import "PreferencesController.h"
#import "Genres.h"
#import "ImageAndTextCell.h"
#import "UtilityFunctions.h"

static FileConversionController		*sharedController						= nil;

@interface FileConversionController (Private)
- (BOOL)	addOneFile:(NSString *)filename atIndex:(NSUInteger)index;
- (void)	clearFileList;
@end

@implementation FileConversionController

+ (FileConversionController *) sharedController
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

- (id) init
{
	if((self = [super initWithWindowNibName:@"FileConversion"])) {
	}
	return self;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if([item action] == @selector(encode:)) {
		[item setTitle:NSLocalizedStringFromTable(@"Convert", @"Menus", @"")];
		return [self encodeAllowed];
	}
	else if([item action] == @selector(downloadAlbumArt:))
	   return 0 != [[_filesController selectedObjects] count];
	else if([item action] == @selector(toggleMetadataInspectorPanel:)) {
		if([_metadataPanel isVisible])
			[item setTitle:NSLocalizedStringFromTable(@"Hide Metadata Inspector", @"Menus", @"")];
		else
			[item setTitle:NSLocalizedStringFromTable(@"Show Metadata Inspector", @"Menus", @"")];
		
		return YES;
	}
	else
		return YES;
}

- (void) awakeFromNib
{
	NSTableColumn	*tableColumn;
	NSCell			*dataCell;
		
	// Set the sort descriptors
	[_filesController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.trackTitle" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.albumArtist" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.albumTitle" ascending:YES] autorelease],
		nil]];

	// Setup the toolbar
	FileConversionToolbar *toolbar = [[FileConversionToolbar alloc] initWithIdentifier:@"org.sbooth.Max.FileConversionToolbar"];
    
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    
    [toolbar setDelegate:toolbar];
	
    [[self window] setToolbar:[toolbar autorelease]];

	// Setup files table
	tableColumn			= [_filesTableView tableColumnWithIdentifier:@"filename"];
	dataCell			= [[ImageAndTextCell alloc] init];
	
	// TOD: Is NSLineBreakByTruncatingMiddle what users would expect?
	[dataCell setLineBreakMode:NSLineBreakByTruncatingMiddle];
	
	[tableColumn setDataCell:dataCell];
	[tableColumn bind:@"value" toObject:_filesController withKeyPath:@"arrangedObjects.displayName" options:nil];
	[dataCell release];
	
	// Set number formatters	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[_trackNumberTextField setFormatter:numberFormatter];
	[_trackTotalTextField setFormatter:numberFormatter];
	[_discNumberTextField setFormatter:numberFormatter];
	[_discTotalTextField setFormatter:numberFormatter];
	[numberFormatter release];	
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"FileConversion"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (NSUInteger)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void)	release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

#pragma mark Action Methods

- (BOOL) encodeAllowed
{
	return (0 != [[_filesController arrangedObjects] count]);
}

- (IBAction) encode:(id)sender
{
	AudioMetadata			*metadata				= nil;
	NSArray					*filenames				= nil;
	NSString				*filename				= nil;
	NSMutableDictionary		*postProcessingOptions	= nil;
	NSArray					*applicationPaths;
	unsigned				i;

	// Encoders
	NSArray *encoders = [[FormatsController sharedController] selectedFormats];
	
	// Verify at least one output format is selected
	if(0 == [encoders count]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"No output formats are selected.", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		NSInteger result = [alert runModal];
		
		if(NSAlertFirstButtonReturn == result) {
			// do nothing
		}
		else if(NSAlertSecondButtonReturn == result) {
			[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
			[[PreferencesController sharedPreferences] showWindow:self];
		}
		
		return;
	}

	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings setValue:encoders forKey:@"encoders"];

	// File locations
	[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] forKey:@"outputDirectory"];
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"convertInPlace"] forKey:@"convertInPlace"];
	[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] stringByExpandingTildeInPath] forKey:@"temporaryDirectory"];
	
	// Conversion parameters
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"saveSettingsInComment"] forKey:@"saveSettingsInComment"];
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"deleteSourceFiles"] forKey:@"deleteSourceFiles"];
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"overwriteOutputFiles"] forKey:@"overwriteOutputFiles"];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"overwriteOutputFiles"]) {
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"promptBeforeOverwritingOutputFiles"] forKey:@"promptBeforeOverwritingOutputFiles"];
	}
	
	// Output file naming
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomOutputFileNaming"]) {
		NSMutableDictionary		*fileNamingFormat = [NSMutableDictionary dictionary];
				
		[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"fileNamingFormat"] forKey:@"formatString"];
		[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"useTwoDigitTrackNumbers"] forKey:@"useTwoDigitTrackNumbers"];
		[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"useNamingFallback"] forKey:@"useNamingFallback"];
		
		[settings setValue:fileNamingFormat forKey:@"outputFileNaming"];
	}
	
	// Post-processing options
	postProcessingOptions = [NSMutableDictionary dictionary];
	
	[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"addToiTunes"] forKey:@"addToiTunes"];
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"addToiTunes"]) {

		[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"addToiTunesPlaylist"] forKey:@"addToiTunesPlaylist"];

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"addToiTunesPlaylist"]) {
			[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"iTunesPlaylistName"] forKey:@"iTunesPlaylistName"];
		}		
	}
		
	applicationPaths	= [[NSUserDefaults standardUserDefaults] objectForKey:@"postProcessingApplications"];
		
	if(0 != [applicationPaths count]) {
		[postProcessingOptions setValue:applicationPaths forKey:@"postProcessingApplications"];
	}
	
	if(0 != [postProcessingOptions count]) {
		[settings setValue:postProcessingOptions forKey:@"postProcessingOptions"];
	}
	
	// Album art
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"saveAlbumArt"]) {
		NSMutableDictionary		*albumArt = [NSMutableDictionary dictionary];
		
		[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileExtension"] forKey:@"extension"];
		[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileNamingFormat"] forKey:@"formatString"];
		
		[settings setValue:albumArt forKey:@"albumArt"];
	}
	
	// Process the files
	filenames = [_filesController arrangedObjects];
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"joinFiles"]) {
		filename	= [[filenames objectAtIndex:0] objectForKey:@"filename"];
		metadata	= [[filenames objectAtIndex:0] objectForKey:@"metadata"];
		
		@try {
			[[EncoderController sharedController] encodeFiles:filenames metadata:metadata settings:settings];
		}
		
		@catch(NSException *exception) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while converting the file \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:filename]]];
			[alert setInformativeText:[exception reason]];
			[alert setAlertStyle:NSWarningAlertStyle];		
			[alert runModal];
		}			
		
	}
	// Iterate through file list and convert each one
	else {
		for(i = 0; i < [filenames count]; ++i) {

			filename	= [[filenames objectAtIndex:i] objectForKey:@"filename"];
			metadata	= [[filenames objectAtIndex:i] objectForKey:@"metadata"];
			
			@try {
				[[EncoderController sharedController] encodeFile:filename metadata:metadata settings:settings];
			}
			
			@catch(NSException *exception) {
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
				[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while converting the file \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:filename]]];
				[alert setInformativeText:[exception reason]];
				[alert setAlertStyle:NSWarningAlertStyle];		
				[alert runModal];
			}			
		}
	}

	// Get ready for next time
//	[[self window] performClose:self];
	[self clearFileList];
}

- (IBAction) toggleMetadataInspectorPanel:(id)sender
{
	if(![_metadataPanel isVisible]) {
		[_metadataPanel orderFront:sender];
	}
	else {
		[_metadataPanel orderOut:sender];
	}
}

- (IBAction) addFiles:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	[panel setAllowedFileTypes:GetAudioExtensions()];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
		if(NSOKButton == result) {
			for(NSURL *url in [panel URLs])
				[self addFile:[url path]];
		}
	}];
}

- (IBAction) removeFiles:(id)sender
{
	[_filesController removeObjects:[_filesController selectedObjects]];	
}

#pragma mark File Management

- (BOOL) addFile:(NSString *)filename
{
	return [self addFile:filename atIndex:/*[[_filesController arrangedObjects] count]*/NSNotFound];
}

- (BOOL) addFile:(NSString *)filename atIndex:(NSUInteger)index
{
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];
	NSAutoreleasePool	*loopPool			= nil;
	NSFileManager		*manager			= [NSFileManager defaultManager];
	NSArray				*allowedTypes		= GetAudioExtensions();
	NSMutableArray		*newFiles;
	NSDictionary		*file;
	NSArray				*subpaths;
	BOOL				isDir;
	NSString			*subpath;
	NSString			*composedPath;
	BOOL				result;
	BOOL				success				= YES;
	
	result = [manager fileExistsAtPath:filename isDirectory:&isDir];
	NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @""));
	
	newFiles = [NSMutableArray array];
	
	if(isDir) {
		subpaths	= [manager subpathsAtPath:filename];
		
		for(subpath in subpaths) {
			loopPool		= [[NSAutoreleasePool alloc] init];
			composedPath	= [NSString stringWithFormat:@"%@/%@", filename, subpath];
			
			// Ignore dotfiles
			if([[subpath lastPathComponent] hasPrefix:@"."]) {
				continue;
			}
			// Ignore files that don't have our extensions
			else if(NO == [allowedTypes containsObject:[[subpath pathExtension] lowercaseString]]) {
				continue;
			}
			
			// Ignore directories
			if([manager fileExistsAtPath:composedPath isDirectory:&isDir] && NO == isDir) {
				success &= [self addOneFile:composedPath atIndex:index];
			}
			
			if(success) {
				file = [_filesController findFile:composedPath];
				if(nil != file) {
					[newFiles addObject:file];
				}
			}
			
			[loopPool release];
		}
		
		if(success) {
			[_filesController setSelectedObjects:newFiles];
		}
	}
	else {
		success &= [self addOneFile:filename atIndex:index];
		if(success) {
			[_filesController selectFile:filename];
		}
	}
	
	[pool release];
	
	return success;
}

#pragma mark Miscellaneous

- (NSArray *)				genres											{ return [Genres sharedGenres]; }

#pragma mark Album Art

- (NSString *) artist
{
	return [[_filesController selection] valueForKeyPath:@"metadata.albumArtist"];
}

- (NSString *) title
{
	return [[_filesController selection] valueForKeyPath:@"metadata.albumTitle"];
}

- (void) setAlbumArt:(NSImage *)albumArt
{
	[[_filesController selection] setValue:albumArt forKeyPath:@"metadata.albumArt"];
}

- (NSWindow *) windowForSheet { return [self window]; }

- (IBAction) downloadAlbumArt:(id)sender
{	
}

- (IBAction) selectAlbumArt:(id) sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowedFileTypes:[NSImage imageFileTypes]];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
	    if(NSOKButton == result) {
			for(NSURL *url in [panel URLs]) {
				NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
				if(nil != image) {
					[[_filesController selection] setValue:[image autorelease] forKeyPath:@"metadata.albumArt"];
				}
			}
		}
	}];
}

#pragma mark NSTableView Delegate Methods

- (void) tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if(_filesTableView == aTableView && [[aTableColumn identifier] isEqualToString:@"filename"]) {
		NSDictionary			*infoForBinding;
		
		infoForBinding			= [aTableView infoForBinding:NSContentBinding];
		
		if(nil != infoForBinding) {
			NSArrayController	*arrayController;
			NSDictionary		*fileDictionary;
			
			arrayController		= [infoForBinding objectForKey:NSObservedObjectKey];
			fileDictionary		= [[arrayController arrangedObjects] objectAtIndex:rowIndex];
			
			[aCell setImage:[fileDictionary valueForKey:@"icon"]];
		}
	}
}

@end

@implementation FileConversionController (Private)

- (BOOL) addOneFile:(NSString *)filename atIndex:(NSUInteger)index
{
	NSImage				*icon			= nil;
	AudioMetadata		*metadata		= nil;
	
	// Don't re-add files
	if([_filesController containsFile:filename]) {
		return YES;
	}
	// Only accept files with our extensions
	else if(NO == [GetAudioExtensions() containsObject:[[filename pathExtension] lowercaseString]]) {	
		return NO;
	}
	
	// Get file's metadata
	@try {
		metadata = [AudioMetadata metadataFromFile:filename];
	}

	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while opening the document \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:filename]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
		
		return NO;
	}
	
	// Get the icon for the file
	icon = GetIconForFile(filename, NSMakeSize(16, 16));
	
	if(NSNotFound == index) {
		[_filesController addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [[NSFileManager defaultManager] displayNameAtPath:filename], icon, metadata, nil] forKeys:[NSArray arrayWithObjects:@"filename", @"displayName", @"icon", @"metadata", nil]]];
	}
	else {
		[_filesController insertObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [[NSFileManager defaultManager] displayNameAtPath:filename], icon, metadata, nil] forKeys:[NSArray arrayWithObjects:@"filename", @"displayName", @"icon", @"metadata", nil]] atArrangedObjectIndex:index];			
	}
	
	return YES;
}

- (void) clearFileList
{
	[_filesController removeObjects:[_filesController arrangedObjects]];
}

@end
