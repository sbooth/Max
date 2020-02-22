/*
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

#import "AlbumArtPreferencesController.h"

enum {	
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

@implementation AlbumArtPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"AlbumArtPreferences"])) {
		return self;		
	}
	return nil;
}

- (void) awakeFromNib
{
	[[_albumArtFormatSpecifierPopUpButton selectedItem] setState:NSOffState];
	[_albumArtFormatSpecifierPopUpButton selectItemAtIndex:-1];
	[_albumArtFormatSpecifierPopUpButton synchronizeTitleAndSelectedItem];
}

- (IBAction) insertAlbumArtFileNamingFormatSpecifier:(id)sender
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
	
	fieldEditor = [_albumArtFileNamingComboBox currentEditor];
	if(nil == fieldEditor) {
		[_albumArtFileNamingComboBox setStringValue:string];
		[_albumArtFileNamingComboBox sendAction:[_albumArtFileNamingComboBox action] to:[_albumArtFileNamingComboBox target]];
	}
	else if([_albumArtFileNamingComboBox textShouldBeginEditing:fieldEditor]) {
		[fieldEditor replaceCharactersInRange:[fieldEditor selectedRange] withString:string];
		[_albumArtFileNamingComboBox textShouldEndEditing:fieldEditor];
	}
}

- (IBAction) saveAlbumArtFileNamingFormat:(id)sender
{
	NSString		*pattern	= [_albumArtFileNamingComboBox stringValue];
	NSMutableArray	*patterns	= nil;
	
	patterns = [[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileNamingPatterns"] mutableCopy];
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
	
	[[NSUserDefaults standardUserDefaults] setValue:patterns forKey:@"albumArtFileNamingPatterns"];

	[patterns release];
}	

@end
