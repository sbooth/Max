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

#import "FileConversionSettingsSheet.h"
#import "FileConversionController.h"
#import "MissingResourceException.h"
#import "UtilityFunctions.h"

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

@interface FileConversionSettingsSheet (Private)
- (void)	didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	updateOutputDirectoryMenuItemImage;
- (void)	selectOutputDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	selectTemporaryDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	updateTemporaryDirectoryMenuItemImage;
@end

@implementation FileConversionSettingsSheet

- (id) init
{
	if((self = [super init])) {

		if(NO == [NSBundle loadNibNamed:@"FileConversionSettingsSheet" owner:self])  {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"FileConversionSettingsSheet.nib" forKey:@"filename"]];
		}
				
		return self;
	}
	
	return nil;
}

- (void) awakeFromNib
{
	NSArray			*patterns			= nil;
	NSArray			*applications		= nil;
	NSDictionary	*application		= nil;
	NSString		*applicationPath	= nil;
	NSDictionary	*applicationEntry	= nil;
	unsigned		i;
	
	// Set the menu item images
	[self updateOutputDirectoryMenuItemImage];
	[self updateTemporaryDirectoryMenuItemImage];
	
	// Select the correct items
	[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
	[_temporaryDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomTemporaryDirectory"] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
	
	// Deselect all items in the File Format Specifier NSPopUpButton
	[[_formatSpecifierPopUpButton selectedItem] setState:NSOffState];
	[_formatSpecifierPopUpButton selectItemAtIndex:-1];
	[_formatSpecifierPopUpButton synchronizeTitleAndSelectedItem];
	
	// Set the value to the most recently-saved pattern
	patterns = [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"conversionFileNamingPatterns"];
	if(0 < [patterns count]) {
		[_fileNamingComboBox setStringValue:[patterns objectAtIndex:0]];
	}
	
	// Set up the list of applications for post processing
	applications = [[NSUserDefaults standardUserDefaults] arrayForKey:@"conversionPostProcessingApplications"];
	for(i = 0; i < [applications count]; ++i) {
		application			= [applications objectAtIndex:i];
		applicationPath		= [application objectForKey:@"path"];
		applicationEntry	= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[application objectForKey:@"selected"], applicationPath, [[applicationPath lastPathComponent] stringByDeletingPathExtension], getIconForFile(applicationPath, NSMakeSize(16, 16)), nil] forKeys:[NSArray arrayWithObjects:@"selected", @"path", @"displayName", @"icon", nil]];

		[_postProcessingActionsController addObject:applicationEntry];
	}

	// Set the sort descriptor
	[_postProcessingActionsController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES] autorelease],
		nil]];
}

- (void) showSheet
{
    [[NSApplication sharedApplication] beginSheet:_sheet modalForWindow:[[FileConversionController sharedController] window] modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction) ok:(id)sender
{
	NSArray				*applications			= nil;
	NSMutableArray		*applicationArray		= nil;
	NSDictionary		*currentApplication		= nil;
	NSDictionary		*application			= nil;
	unsigned			i;

	// Save post-processing application paths to defaults
	applications		= [_postProcessingActionsController arrangedObjects];
	applicationArray	= [NSMutableArray arrayWithCapacity:[applications count]];
	for(i = 0; i < [applications count]; ++i) {
		currentApplication	= [applications objectAtIndex:i];
		application			= [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[currentApplication objectForKey:@"selected"], [currentApplication objectForKey:@"path"], nil] forKeys:[NSArray arrayWithObjects:@"selected", @"path", nil]];

		[applicationArray addObject:application];
	}
	[[NSUserDefaults standardUserDefaults] setValue:applicationArray forKey:@"conversionPostProcessingApplications"];
	
	// We're finished
    [[NSApplication sharedApplication] endSheet:_sheet];
}

- (void) didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut:self];
	[self autorelease];
}

- (IBAction) selectOutputDirectory:(id)sender
{
	NSOpenPanel		*panel			= nil;
	int				returnCode		= 0;
	NSArray			*filesToOpen;
	NSString		*dirname;
	unsigned		count, i;
	
	switch([[sender selectedItem] tag]) {
		case kCurrentDirectoryMenuItemTag:
			[[NSWorkspace sharedWorkspace] selectFile:[[[NSUserDefaults standardUserDefaults] stringForKey:@"conversionOutputDirectory"] stringByExpandingTildeInPath] inFileViewerRootedAtPath:nil];
			[[FileConversionController sharedController] setConvertInPlace:NO];
			break;
			
		case kChooseDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			returnCode = [panel runModalForTypes:nil];
			
			switch(returnCode) {
				
				case NSOKButton:
					filesToOpen		= [panel filenames];
					count			= [filesToOpen count];
					
					for(i = 0; i < count; ++i) {
						dirname = [filesToOpen objectAtIndex:i];
						[[NSUserDefaults standardUserDefaults] setObject:[dirname stringByAbbreviatingWithTildeInPath] forKey:@"conversionOutputDirectory"];
						[self updateOutputDirectoryMenuItemImage];
					}
						
					[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
					break;
					
				case NSCancelButton:
					[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
					break;
			}
				
			break;
			
		case kSameAsSourceFileMenuItemTag:
			[[FileConversionController sharedController] setConvertInPlace:YES];
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
		[_fileNamingComboBox sendAction:[_fileNamingComboBox action] to:[_fileNamingComboBox target]];
	}
	else if([_fileNamingComboBox textShouldBeginEditing:fieldEditor]) {
		[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
		[_fileNamingComboBox textShouldEndEditing:fieldEditor];
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
		// Keep pattern from being released (it belongs to the combo box)
		[patterns removeObject:[pattern retain]];
	}	
	
	[patterns insertObject:pattern atIndex:0];
	
	while(10 < [patterns count]) {
		[patterns removeLastObject];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:patterns forKey:@"conversionFileNamingPatterns"];	
	[[FileConversionController sharedController] setFileNamingFormat:pattern];
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
			
			[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[[FileConversionController sharedController] window] modalDelegate:self didEndSelector:@selector(selectTemporaryDirectoryDidEnd:returnCode:contextInfo:) contextInfo:nil];
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
				[[NSUserDefaults standardUserDefaults] setValue:[dirname stringByAbbreviatingWithTildeInPath] forKey:@"conversionTemporaryDirectory"];
				[self updateTemporaryDirectoryMenuItemImage];
			}
				
				[_temporaryDirectoryPopUpButton selectItemWithTag:kCurrentTempDirectoryMenuItemTag];	
			break;
			
		case NSCancelButton:
			[_temporaryDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"conversionUseCustomTemporaryDirectory"] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
			break;
	}	
}

- (void) updateOutputDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [[[NSUserDefaults standardUserDefaults] stringForKey:@"conversionOutputDirectory"] stringByExpandingTildeInPath];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_outputDirectoryPopUpButton itemAtIndex:[_outputDirectoryPopUpButton indexOfItemWithTag:kCurrentDirectoryMenuItemTag]];	
	
	[menuItem setTitle:[path lastPathComponent]];
	[menuItem setImage:image];
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

- (IBAction) addPostProcessingApplication:(id)sender
{
	NSOpenPanel		*panel		= [NSOpenPanel openPanel];
	
	if(NSOKButton == [panel runModalForTypes:[NSArray arrayWithObject:@"app"]]) {
		NSArray				*applications		= [panel filenames];
		NSDictionary		*application		= nil;
		NSString			*applicationPath	= nil;
		unsigned			i;
		
		for(i = 0; i < [applications count]; ++i) {
			applicationPath = [applications objectAtIndex:i];
			application		= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithBool:YES], applicationPath, [[applicationPath lastPathComponent] stringByDeletingPathExtension], getIconForFile(applicationPath, NSMakeSize(16, 16)), nil] forKeys:[NSArray arrayWithObjects:@"selected", @"path", @"displayName", @"icon", nil]];
			[_postProcessingActionsController addObject:application];
		}
	}
}

@end
