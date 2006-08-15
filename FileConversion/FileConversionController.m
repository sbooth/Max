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
#import "FileConversionSettingsSheet.h"
#import "ConverterController.h"
#import "PreferencesController.h"
#import "Genres.h"
#import "AmazonAlbumArtSheet.h"
#import "UtilityFunctions.h"
#import "IOException.h"
#import "MissingResourceException.h"

static FileConversionController		*sharedController						= nil;
static NSString						*ToggleMetadataToolbarItemIdentifier	= @"org.sbooth.Max.FileConversion.ToggleMetadata";
static NSString						*ShowSettingsToolbarItemIdentifier		= @"org.sbooth.Max.FileConversion.ShowSettings";
static NSString						*AlbumArtToolbarItemIdentifier			= @"org.sbooth.Max.FileConversion.ShowAlbumArt";

@interface FileConversionController (Private)
- (void)	addFilesPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (BOOL)	addOneFile:(NSString *)filename atIndex:(unsigned)index;
- (void)	clearFileList;
- (void)	selectAlbumArtPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	showSettingsSheet:(id)sender;
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
	[_fileNamingFormat release];
	[super dealloc];
}

- (void) awakeFromNib
{
	NSToolbar	*toolbar	= nil;
	
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
		
/*	NSOpenPanel *panel = [NSOpenPanel openPanel];
	if(NSOKButton == [panel runModalForTypes:[NSArray arrayWithObject:@"app"]]) {
		NSLog(@"%@", [panel filenames]);
	}*/

	// Setup the toolbar
    toolbar = [[[NSToolbar alloc] initWithIdentifier:@"org.sbooth.Max.FileConversion.ToolbarIdentifier"] autorelease];
    
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbar setDelegate:self];
	
    [[self window] setToolbar:toolbar];
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
	AudioMetadata			*metadata				= nil;
	NSArray					*encoders				= nil;
	NSArray					*filenames				= nil;
	NSString				*outputDirectory		= nil;
	NSString				*filename				= nil;
	NSMutableDictionary		*userInfo				= nil;
	NSMutableDictionary		*postProcessingOptions	= nil;
	int						deleteSourceFilesTag	= 0;
	unsigned				i;

	encoders = [[_encodersController arrangedObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"conversionSelected == 1"]];
	
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

	userInfo			= [NSMutableDictionary dictionary];

	// Temporary files location
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomTemporaryDirectory"]) {
		[userInfo setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"conversionTemporaryDirectory"] stringByExpandingTildeInPath] forKey:@"temporaryDirectory"];
	}
	
	// Conversion parameters
	outputDirectory		= ([self convertInPlace] ? nil : [[[NSUserDefaults standardUserDefaults] stringForKey:@"conversionOutputDirectory"] stringByExpandingTildeInPath]);
	
	[userInfo setObject:[NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"conversionOverwriteExistingFiles"]] forKey:@"overwriteExistingFiles"];
	
	deleteSourceFilesTag = [[NSUserDefaults standardUserDefaults] boolForKey:@"conversionDeleteSourceFiles"];
	if(kOverwriteExistingFiles == deleteSourceFilesTag) {
		[userInfo setObject:[NSNumber numberWithBool:YES] forKey:@"deleteSourceFiles"];
	}
	else {
		[userInfo setObject:[NSNumber numberWithBool:NO] forKey:@"deleteSourceFiles"];
	}
	
	// Setup custom output file naming
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomNaming"]) {
		NSMutableDictionary		*fileNamingFormat = [NSMutableDictionary dictionary];
		
		[fileNamingFormat setObject:[self fileNamingFormat] forKey:@"fileNamingFormat"];
		[fileNamingFormat setObject:[NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseTwoDigitTrackNumbers"]] forKey:@"useTwoDigitTrackNumbers"];
		[fileNamingFormat setObject:[NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseFallback"]] forKey:@"useFallback"];
		
		[userInfo setObject:fileNamingFormat forKey:@"fileNamingFormat"];
	}
	
	// Post-processing options
	postProcessingOptions = [NSMutableDictionary dictionary];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionAddOutputFilesToiTunes"]) {
		[postProcessingOptions setObject:[NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"conversionAddOutputFilesToiTunes"]] forKey:@"addOutputFilesToiTunes"];
	}
	
	NSArray			*selectedApplications;
	NSMutableArray	*postProcessingApplications;
	
	selectedApplications			= [[[NSUserDefaults standardUserDefaults] arrayForKey:@"conversionPostProcessingApplications"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selected == 1"]];
	postProcessingApplications		= [NSMutableArray arrayWithCapacity:[selectedApplications count]];
	
	for(i = 0; i < [selectedApplications count]; ++i) {
		[postProcessingApplications addObject:[[selectedApplications objectAtIndex:i] objectForKey:@"path"]];
	}
	
	if(0 != [postProcessingApplications count]) {
		[postProcessingOptions setObject:postProcessingApplications forKey:@"postProcessingApplications"];
	}
	
	if(0 != [postProcessingOptions count]) {
		[userInfo setObject:postProcessingOptions forKey:@"postProcessingOptions"];
	}
	
	// Iterate through file list and convert each one
	filenames = [_filesController arrangedObjects];
	for(i = 0; i < [filenames count]; ++i) {

		filename	= [[filenames objectAtIndex:i] objectForKey:@"filename"];
		metadata	= [[filenames objectAtIndex:i] objectForKey:@"metadata"];
		
		@try {
			[[ConverterController sharedController] convertFile:filename metadata:metadata withEncoders:encoders toDirectory:outputDirectory userInfo:userInfo];
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
	
	[panel beginSheetForDirectory:nil file:nil types:getAudioExtensions() modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(addFilesPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];	
}

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

- (IBAction) removeFiles:(id)sender
{
	[_filesController removeObjects:[_filesController selectedObjects]];	
}

- (void) openFormatsPreferences
{
	[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
	[[PreferencesController sharedPreferences] showWindow:self];
}

- (void) showSettingsSheet:(id)sender
{
	FileConversionSettingsSheet *sheet = [[FileConversionSettingsSheet alloc] init];
	[sheet showSheet];
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

- (BOOL)					convertInPlace									{ return _convertInPlace; }
- (void)					setConvertInPlace:(BOOL)convertInPlace			{ _convertInPlace = convertInPlace; }

- (NSString *)				fileNamingFormat								{ return _fileNamingFormat; }
- (void)					setFileNamingFormat:(NSString *)fileNamingFormat { [_fileNamingFormat release]; _fileNamingFormat = fileNamingFormat; }

- (void) clearFileList
{
	[_filesController removeObjects:[_filesController arrangedObjects]];
}

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
	NSArray		*filenames		= [_filesController selectedObjects];
	unsigned	i;
	
	for(i = 0; i < [filenames count]; ++i) {					
		[[[filenames objectAtIndex:i] objectForKey:@"metadata"] setAlbumArt:albumArt];
	}
}

- (NSWindow *) windowForSheet { return [self window]; }

- (IBAction) downloadAlbumArt:(id) sender
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

- (void) selectAlbumArtPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(NSOKButton == returnCode) {
		NSArray		*filesToOpen	= [sheet filenames];
		unsigned	count			= [filesToOpen count];
		unsigned	i;
		NSImage		*image			= nil;
		
		for(i = 0; i < count; ++i) {
			image = [[[NSImage alloc] initWithContentsOfFile:[filesToOpen objectAtIndex:i]] autorelease];
			if(nil != image) {
				[[_filesController selection] setValue:image forKeyPath:@"metadata.albumArt"];
			}
		}
	}	
}

#pragma mark NSToolbar Delegate Methods

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdentifier isEqualToString:ToggleMetadataToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Metadata", @"FileConversion", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Metadata", @"FileConversion", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Show or hide the metadata associated with the selected files", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"TrackInfoToolbarImage"]];
		
		[toolbarItem setTarget:_metadataDrawer];
		[toolbarItem setAction:@selector(toggle:)];
	}
	else if([itemIdentifier isEqualToString:ShowSettingsToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Settings", @"FileConversion", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Settings", @"FileConversion", @"")];		
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"View or change the file conversion options", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"SettingsToolbarImage"]];
		
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showSettingsSheet:)];
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
    return [NSArray arrayWithObjects: ToggleMetadataToolbarItemIdentifier, AlbumArtToolbarItemIdentifier,
		NSToolbarSpaceItemIdentifier, ShowSettingsToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: ToggleMetadataToolbarItemIdentifier, AlbumArtToolbarItemIdentifier, ShowSettingsToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

@end
