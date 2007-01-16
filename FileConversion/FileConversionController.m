/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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
#import "EncoderController.h"
#import "PreferencesController.h"
#import "Genres.h"
#import "AmazonAlbumArtSheet.h"
#import "ImageAndTextCell.h"
#import "UtilityFunctions.h"

static FileConversionController		*sharedController						= nil;

static NSString						*MetadataToolbarItemIdentifier			= @"org.sbooth.Max.FileConversion.Toolbar.Metadata";
static NSString						*AlbumArtToolbarItemIdentifier			= @"org.sbooth.Max.FileConversion.Toolbar.AlbumArt";

@interface FileConversionController (Private)
- (void)	addFilesPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (BOOL)	addOneFile:(NSString *)filename atIndex:(unsigned)index;
- (void)	clearFileList;
- (void)	selectAlbumArtPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation FileConversionController

+ (void) initialize
{
	[self setKeys:[NSArray arrayWithObject:@"metadata.albumArt"] triggerChangeNotificationsForDependentKey:@"albumArtWidth"];
	[self setKeys:[NSArray arrayWithObject:@"metadata.albumArt"] triggerChangeNotificationsForDependentKey:@"albumArtHeight"];
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

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	BOOL result;
	
	switch([item tag]) {
		default:								result = [super validateMenuItem:item];			break;
		case kDownloadAlbumArtMenuItemTag:		result = (0 != [[_filesController arrangedObjects] count]);	break;
	}
	
	return result;
}

- (void) awakeFromNib
{
	NSTableColumn	*tableColumn;
	NSCell			*dataCell;
	
	NSToolbar		*toolbar	= nil;
	
	// Set the sort descriptors
	[_filesController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.trackTitle" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.albumArtist" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"metadata.albumTitle" ascending:YES] autorelease],
		nil]];

	[_encodersController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease],
		[[[NSSortDescriptor alloc] initWithKey:@"nickname" ascending:YES] autorelease],
		nil]];

	// Setup the toolbar
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"org.sbooth.Max.FileConversion.Toolbar"];
    
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:[toolbar autorelease]];

	// Setup files table
	tableColumn			= [_filesTableView tableColumnWithIdentifier:@"filename"];
	dataCell			= [[ImageAndTextCell alloc] init];
	
	[tableColumn setDataCell:dataCell];
	[tableColumn bind:@"value" toObject:_filesController withKeyPath:@"arrangedObjects.displayName" options:nil];
	[dataCell release];		
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

- (IBAction) convert:(id)sender
{
	AudioMetadata			*metadata				= nil;
	NSArray					*encoders				= nil;
	NSArray					*filenames				= nil;
	NSString				*filename				= nil;
	NSMutableDictionary		*settings				= nil;
	NSMutableDictionary		*postProcessingOptions	= nil;
	NSArray					*applicationPaths;
	unsigned				i;

	encoders = [[_encodersController arrangedObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selected == 1"]];
	
	// Verify at least one output format is selected
	if(0 == [encoders count]) {
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

	settings			= [NSMutableDictionary dictionary];

	// Encoders
	[settings setValue:encoders forKey:@"encoders"];

	// File locations
	[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] forKey:@"outputDirectory"];
	[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"convertInPlace"] forKey:@"convertInPlace"];
	[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] stringByExpandingTildeInPath] forKey:@"temporaryDirectory"];
	
	// Conversion parameters
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

- (IBAction) addFiles:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:YES];
	[panel setCanChooseDirectories:YES];
	
	[panel beginSheetForDirectory:nil file:nil types:getAudioExtensions() modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(addFilesPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];	
}

- (IBAction) removeFiles:(id)sender
{
	[_filesController removeObjects:[_filesController selectedObjects]];	
}

- (IBAction) setupEncoders:(id)sender
{
	[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
	[[PreferencesController sharedPreferences] showWindow:self];
}

#pragma mark File Management

- (BOOL) addFile:(NSString *)filename
{
	return [self addFile:filename atIndex:/*[[_filesController arrangedObjects] count]*/NSNotFound];
}

- (BOOL) addFile:(NSString *)filename atIndex:(unsigned)index
{
	NSAutoreleasePool	*pool				= [[NSAutoreleasePool alloc] init];
	NSAutoreleasePool	*loopPool			= nil;
	NSFileManager		*manager			= [NSFileManager defaultManager];
	NSArray				*allowedTypes		= getAudioExtensions();
	NSMutableArray		*newFiles;
	NSDictionary		*file;
	NSArray				*subpaths;
	BOOL				isDir;
	NSEnumerator		*enumerator;
	NSString			*subpath;
	NSString			*composedPath;
	BOOL				result;
	BOOL				success				= YES;
	
	result = [manager fileExistsAtPath:filename isDirectory:&isDir];
	NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @""));
	
	newFiles = [NSMutableArray array];
	
	if(isDir) {
		subpaths	= [manager subpathsAtPath:filename];
		enumerator	= [subpaths objectEnumerator];
		
		while((subpath = [enumerator nextObject])) {
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
				success &= [self addOneFile:composedPath atIndex:(unsigned)index];
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
		success &= [self addOneFile:filename atIndex:(unsigned)index];
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

- (unsigned) albumArtWidth	{ return [[[_filesController selection] valueForKeyPath:@"metadata.albumArt"] size].width; }
- (unsigned) albumArtHeight	{ return [[[_filesController selection] valueForKeyPath:@"metadata.albumArt"] size].height; }

- (void) setAlbumArt:(NSImage *)albumArt
{
	[[_filesController selection] setValue:albumArt forKeyPath:@"metadata.albumArt"];
}

- (NSWindow *) windowForSheet { return [self window]; }

- (IBAction) downloadAlbumArt:(id)sender
{	
	AmazonAlbumArtSheet *art = [[[AmazonAlbumArtSheet alloc] initWithSource:self] autorelease];
	[art showAlbumArtMatches];
}

- (IBAction) selectAlbumArt:(id) sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	
	[panel beginSheetForDirectory:nil file:nil types:[NSImage imageFileTypes] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(selectAlbumArtPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

#pragma mark NSToolbar Delegate Methods

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdentifier isEqualToString:MetadataToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Metadata", @"FileConversion", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Metadata", @"FileConversion", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Show or hide the metadata associated with the selected files", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"TrackInfoToolbarImage"]];
		
		[toolbarItem setTarget:_metadataDrawer];
		[toolbarItem setAction:@selector(toggle:)];
	}
    else if([itemIdentifier isEqualToString:AlbumArtToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Album Art", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Album Art", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Show or hide the artwork associated with the selected files", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"AlbumArtToolbarImage"]];
		
		[toolbarItem setTarget:_artDrawer];
		[toolbarItem setAction:@selector(toggle:)];
	}
	else {
		toolbarItem = nil;
    }
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects: MetadataToolbarItemIdentifier, AlbumArtToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: MetadataToolbarItemIdentifier, AlbumArtToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier, nil];
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

- (void) addFilesPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
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

- (BOOL) addOneFile:(NSString *)filename atIndex:(unsigned)index
{
	NSImage				*icon			= nil;
	AudioMetadata		*metadata		= nil;
	
	// Don't re-add files
	if([_filesController containsFile:filename]) {
		return YES;
	}
	// Only accept files with our extensions
	else if(NO == [getAudioExtensions() containsObject:[[filename pathExtension] lowercaseString]]) {	
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
	icon = getIconForFile(filename, NSMakeSize(16, 16));
	
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

- (void) selectAlbumArtPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		NSArray		*filesToOpen	= [sheet filenames];
		unsigned	count			= [filesToOpen count];
		unsigned	i;
		NSImage		*image			= nil;
		
		for(i = 0; i < count; ++i) {
			image = [[NSImage alloc] initWithContentsOfFile:[filesToOpen objectAtIndex:i]];
			if(nil != image) {
				[[_filesController selection] setValue:[image autorelease] forKeyPath:@"metadata.albumArt"];
			}
		}
	}
}

@end
