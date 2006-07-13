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

#import "OutputPreferencesController.h"
#import "PreferencesController.h"

enum {
	kDiscNumberButton		= 12,
	kDiscsInSetButton		= 1,
	kDiscArtistButton		= 2,
	kDiscTitleButton		= 3,
	kDiscGenreButton		= 4,
	kDiscYearButton			= 5,
	kTrackNumberButton		= 6,
	kTrackArtistButton		= 7,
	kTrackTitleButton		= 8,
	kTrackGenreButton		= 9,
	kTrackYearButton		= 10,
	kFileFormatButton		= 11,
};

@interface OutputPreferencesController (Private)
- (void)	updateOutputDirectoryMenuItemImage;
- (void)	updateTemporaryDirectoryMenuItemImage;

- (void)	selectOutputDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)	selectTemporaryDirectoryDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
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
	// Set the menu item images
	[self updateOutputDirectoryMenuItemImage];
	[self updateTemporaryDirectoryMenuItemImage];
	
	// Select the correct items
	[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];
	[_temporaryDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"] ? kCurrentDirectoryMenuItemTag : kDefaultDirectoryMenuItemTag)];	

	// Update the example track text field
	[self controlTextDidChange:nil];
}
	
- (IBAction)customNamingButtonAction:(id)sender
{
	NSString *string;
	
	switch([(NSButton *)sender tag]) {
		case kDiscNumberButton:			string = @"{discNumber}";		break;
		case kDiscsInSetButton:			string = @"{discsInSet}";		break;
		case kDiscArtistButton:			string = @"{discArtist}";		break;
		case kDiscTitleButton:			string = @"{discTitle}";		break;
		case kDiscGenreButton:			string = @"{discGenre}";		break;
		case kDiscYearButton:			string = @"{discYear}";			break;
		case kTrackNumberButton:		string = @"{trackNumber}";		break;
		case kTrackArtistButton:		string = @"{trackArtist}";		break;
		case kTrackTitleButton:			string = @"{trackTitle}";		break;
		case kTrackGenreButton:			string = @"{trackGenre}";		break;
		case kTrackYearButton:			string = @"{trackYear}";		break;
		case kFileFormatButton:			string = @"{fileFormat}";		break;
	}
	
	NSText *fieldEditor = [_customNameTextField currentEditor];
	if(nil == fieldEditor) {
		[_customNameTextField setStringValue:string];
	}
	else {
		if([_customNameTextField textShouldBeginEditing:fieldEditor]) {
			[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
			[_customNameTextField textShouldEndEditing:fieldEditor];
			[self controlTextDidChange:nil];
		}
	}
}

- (void) updateOutputDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_outputDirectoryPopUpButton itemAtIndex:[_outputDirectoryPopUpButton indexOfItemWithTag:kCurrentDirectoryMenuItemTag]];	
	
	[menuItem setTitle:[path lastPathComponent]];
	[menuItem setImage:image];
}

- (IBAction) selectOutputDirectory:(id)sender
{
	NSOpenPanel *panel = nil;
	
	switch([[sender selectedItem] tag]) {
		case kCurrentDirectoryMenuItemTag:
			[[NSWorkspace sharedWorkspace] selectFile:[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] inFileViewerRootedAtPath:nil];
			break;
			
		case kChooseDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[[PreferencesController sharedPreferences] window] modalDelegate:self didEndSelector:@selector(selectOutputDirectoryDidEnd:returnCode:contextInfo:) contextInfo:nil];
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
				[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:[dirname stringByAbbreviatingWithTildeInPath] forKey:@"outputDirectory"];
				[self updateOutputDirectoryMenuItemImage];
			}

			[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
			break;

		case NSCancelButton:
			[_outputDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
			break;
	}
}

- (void) updateTemporaryDirectoryMenuItemImage
{
	NSMenuItem	*menuItem	= nil;
	NSString	*path		= nil;
	NSImage		*image		= nil;
	
	// Set the menu item image for the output directory
	path		= [[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"];
	image		= getIconForFile(path, NSMakeSize(16, 16));
	menuItem	= [_temporaryDirectoryPopUpButton itemAtIndex:[_temporaryDirectoryPopUpButton indexOfItemWithTag:kCurrentDirectoryMenuItemTag]];	
	
	[menuItem setTitle:[path lastPathComponent]];
	[menuItem setImage:image];
}

- (IBAction) selectTemporaryDirectory:(id)sender
{
	NSOpenPanel *panel = nil;
	
	switch([[sender selectedItem] tag]) {
		case kDefaultDirectoryMenuItemTag:
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"useCustomTmpDirectory"];
			break;
			
		case kCurrentDirectoryMenuItemTag:
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
				[[NSWorkspace sharedWorkspace] selectFile:[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] inFileViewerRootedAtPath:nil];
			}
			else {
				[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:@"useCustomTmpDirectory"]; 
			}
			break;
			
		case kChooseDirectoryMenuItemTag:
			panel = [NSOpenPanel openPanel];
			
			[panel setAllowsMultipleSelection:NO];
			[panel setCanChooseDirectories:YES];
			[panel setCanChooseFiles:NO];
			
			[panel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[[PreferencesController sharedPreferences] window] modalDelegate:self didEndSelector:@selector(selectTemporaryDirectoryDidEnd:returnCode:contextInfo:) contextInfo:nil];
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
				[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:@"useCustomTmpDirectory"]; 
				[[NSUserDefaults standardUserDefaults] setValue:dirname forKey:@"tmpDirectory"];
				[self updateTemporaryDirectoryMenuItemImage];
			}
				
				[_temporaryDirectoryPopUpButton selectItemWithTag:kCurrentDirectoryMenuItemTag];	
			break;
			
		case NSCancelButton:
			[_temporaryDirectoryPopUpButton selectItemWithTag:([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"] ? kCurrentDirectoryMenuItemTag : kDefaultDirectoryMenuItemTag)];	
			break;
	}	
}

#pragma mark Delegate methods

- (void) controlTextDidChange:(NSNotification *)aNotification
{
	NSString *scheme = [_customNameTextField stringValue];
	if(nil == scheme) {
		scheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
	}
	// No love
	if(nil == scheme) {
		return;
	}
	
	NSMutableString *sample = [NSMutableString stringWithCapacity:[scheme length]];
	[sample setString:scheme];		
	
	[sample replaceOccurrencesOfString:@"{discNumber}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discsInSet}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discArtist}"		withString:@"Nirvana" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discTitle}"		withString:@"MTV Unplugged in New York" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discGenre}"		withString:@"Grunge" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{discYear}"		withString:@"1994" options:nil range:NSMakeRange(0, [sample length])];
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"customNamingUseTwoDigitTrackNumbers"]) {
		[sample replaceOccurrencesOfString:@"{trackNumber}"		withString:@"04" options:nil range:NSMakeRange(0, [sample length])];
	}
	else {
		[sample replaceOccurrencesOfString:@"{trackNumber}"		withString:@"4" options:nil range:NSMakeRange(0, [sample length])];
	}
	[sample replaceOccurrencesOfString:@"{trackArtist}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackTitle}"		withString:@"The Man Who Sold the World" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackGenre}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{trackYear}"		withString:@"" options:nil range:NSMakeRange(0, [sample length])];
	[sample replaceOccurrencesOfString:@"{fileFormat}"		withString:@"FLAC" options:nil range:NSMakeRange(0, [sample length])];
	
	[self setValue:sample forKey:@"customNameExample"];
}

@end
