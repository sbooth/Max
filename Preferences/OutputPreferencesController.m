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

#import "OutputPreferencesController.h"
#import "PreferencesController.h"
#import "UtilityFunctions.h"

enum {
	kCurrentDirectoryMenuItemTag		= 1,
	kChooseDirectoryMenuItemTag			= 2,
	kSameAsSourceFileMenuItemTag		= 3,
	
	kCurrentTempDirectoryMenuItemTag	= 1,
	kChooseTempDirectoryMenuItemTag		= 2,
	kDefaultTempDirectoryMenuItemTag	= 3,
	
	kAlbumTitleMenuItem					= 1,
	kAlbumArtistMenuItem				= 2,
	kAlbumYearMenuItem					= 3,
	kAlbumGenreMenuItem					= 4,
	kAlbumComposerMenuItem				= 5,
	kTrackTitleMenuItem					= 6,
	kTrackArtistMenuItem				= 7,
	kTrackYearMenuItem					= 8,
	kTrackGenreMenuItem					= 9,
	kTrackComposerMenuItem				= 10,
	kTrackNumberMenuItemTag				= 11,
	kTrackTotalMenuItemTag				= 12,
	kFileFormatMenuItemTag				= 13,
	kDiscNumberMenuItemTag				= 14,
	kDiscTotalMenuItemTag				= 15,
	kSourceFilenameMenuItemTag			= 16
};

@interface OutputPreferencesController (Private)
- (void)	updateOutputDirectoryMenuItemImage;
- (void)	updateTemporaryDirectoryMenuItemImage;
@end

@implementation OutputPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"OutputPreferences"])) {
		return self;		
	}
	return nil;
}

- (void) awakeFromNib
{
	//	NSString		*outputDirectory;
	//	NSArray			*patterns			= nil;
	//	unsigned		i;
	
	// Set the menu item images
	[self updateOutputDirectoryMenuItemImage];
	[self updateTemporaryDirectoryMenuItemImage];
	
	// Select the correct items
	[_outputDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"convertInPlace"] ? kSameAsSourceFileMenuItemTag : kCurrentDirectoryMenuItemTag)];	
	[_temporaryDirectoryPopUpButton selectItemWithTag:(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];	
	
	// Deselect all items in the File Format Specifier NSPopUpButton
	[[_formatSpecifierPopUpButton selectedItem] setState:NSOffState];
	[_formatSpecifierPopUpButton selectItemAtIndex:-1];
	[_formatSpecifierPopUpButton synchronizeTitleAndSelectedItem];
		
	// Set the value to the most recently-saved pattern
	/*	patterns = [_settings objectForKey:@"fileNamingPatterns"];
	if(0 < [patterns count]) {
		[_fileNamingComboBox setStringValue:[patterns objectAtIndex:0]];
	}*/	
}

- (IBAction) selectOutputDirectory:(id)sender
{
	NSOpenPanel		*panel			= nil;
	
	switch([[sender selectedItem] tag]) {
		case kCurrentDirectoryMenuItemTag:
			[[NSWorkspace sharedWorkspace] selectFile:[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] inFileViewerRootedAtPath:@""];
			break;
			
		case kChooseDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanCreateDirectories:YES];
			[panel setCanChooseFiles:NO];

			[panel beginSheetModalForWindow:[[PreferencesController sharedPreferences] window] completionHandler:^(NSModalResponse result) {
				[panel orderOut:self];

				switch(result) {

					case NSOKButton:
						for(NSURL *url in [panel URLs]) {
							[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"convertInPlace"];
							[[NSUserDefaults standardUserDefaults] setObject:[[url path] stringByAbbreviatingWithTildeInPath] forKey:@"outputDirectory"];
							[self updateOutputDirectoryMenuItemImage];
						}

						[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
						break;

					case NSCancelButton:
						[self updateOutputDirectoryMenuItemImage];
						[_outputDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"convertInPlace"] ? kSameAsSourceFileMenuItemTag : kCurrentDirectoryMenuItemTag)];
						break;
				}
			}];

			break;
			
		case kSameAsSourceFileMenuItemTag:
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"convertInPlace"];
//			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"outputDirectory"];
			[self updateOutputDirectoryMenuItemImage];
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
		case kAlbumYearMenuItem:			string = @"{albumDate}";		break;
		case kAlbumGenreMenuItem:			string = @"{albumGenre}";		break;
		case kAlbumComposerMenuItem:		string = @"{albumComposer}";	break;
		case kTrackTitleMenuItem:			string = @"{trackTitle}";		break;
		case kTrackArtistMenuItem:			string = @"{trackArtist}";		break;
		case kTrackYearMenuItem:			string = @"{trackDate}";		break;
		case kTrackGenreMenuItem:			string = @"{trackGenre}";		break;
		case kTrackComposerMenuItem:		string = @"{trackComposer}";	break;
		case kTrackNumberMenuItemTag:		string = @"{trackNumber}";		break;
		case kTrackTotalMenuItemTag:		string = @"{trackTotal}";		break;
		case kFileFormatMenuItemTag:		string = @"{fileFormat}";		break;
		case kDiscNumberMenuItemTag:		string = @"{discNumber}";		break;
		case kDiscTotalMenuItemTag:			string = @"{discTotal}";		break;
		case kSourceFilenameMenuItemTag:	string = @"{sourceFilename}";	break;
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
	
	patterns = [[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"fileNamingPatterns"] mutableCopy];
	if(nil == patterns) {
		patterns = [[NSMutableArray alloc] init];
	}
	
	if([patterns containsObject:pattern]) {
		// Keep pattern from being released (it belongs to the combo box)
		[patterns removeObject:[pattern retain]];
	}	
	
	[patterns insertObject:pattern atIndex:0];
	
	while(10 < [patterns count]) {
		[patterns removeLastObject];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:patterns forKey:@"fileNamingPatterns"];

	[patterns release];
}	

- (IBAction) selectTemporaryDirectory:(id)sender
{
	NSOpenPanel		*panel			= nil;
	
	switch([[sender selectedItem] tag]) {
		case kDefaultTempDirectoryMenuItemTag:
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"temporaryDirectory"];
			[self updateTemporaryDirectoryMenuItemImage];
			break;
			
		case kCurrentTempDirectoryMenuItemTag:
			[[NSWorkspace sharedWorkspace] selectFile:[[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] inFileViewerRootedAtPath:@""];
			break;
			
		case kChooseTempDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanCreateDirectories:YES];
			[panel setCanChooseFiles:NO];

			[panel beginSheetModalForWindow:[[PreferencesController sharedPreferences] window] completionHandler:^(NSModalResponse result) {
				[panel orderOut:self];

				switch(result) {

					case NSOKButton:
						for(NSURL *url in [panel URLs]) {
							[[NSUserDefaults standardUserDefaults] setObject:[[url path] stringByAbbreviatingWithTildeInPath] forKey:@"temporaryDirectory"];
							[self updateTemporaryDirectoryMenuItemImage];
						}

						[_temporaryDirectoryPopUpButton selectItemWithTag:kCurrentTempDirectoryMenuItemTag];
						break;

					case NSCancelButton:
						[_temporaryDirectoryPopUpButton selectItemWithTag:(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] ? kCurrentTempDirectoryMenuItemTag : kDefaultTempDirectoryMenuItemTag)];
						break;
				}
			}];

			break;
	}
}

@end

@implementation OutputPreferencesController (Private)

- (void) updateOutputDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	menuItem	= [_outputDirectoryPopUpButton itemAtIndex:[_outputDirectoryPopUpButton indexOfItemWithTag:kCurrentDirectoryMenuItemTag]];	

	// If we are converting in place, reset the menu's title and image
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"convertInPlace"]) {
		[menuItem setTitle:NSLocalizedStringFromTable(@"Not Specified", @"FileConversion", @"")];
		[menuItem setImage:nil];
		return;
	}
	
	// Set the menu item image for the output directory
	path		= [[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath];
	image		= GetIconForFile(path, NSMakeSize(16, 16));
	
	[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[menuItem setImage:image];
}

- (void) updateTemporaryDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"];
	image		= GetIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_temporaryDirectoryPopUpButton itemAtIndex:[_temporaryDirectoryPopUpButton indexOfItemWithTag:kCurrentTempDirectoryMenuItemTag]];
	
	if(nil != path) {
		[menuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
		[menuItem setImage:image];
	}
	else {
		[menuItem setTitle:NSLocalizedStringFromTable(@"Not Specified", @"FileConversion", @"")];
		[menuItem setImage:nil];
	}
}

@end
