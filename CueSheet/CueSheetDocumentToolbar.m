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

#import "CueSheetDocumentToolbar.h"

static NSString		*EncodeToolbarItemIdentifier				= @"org.sbooth.Max.CueSheetDocument.Toolbar.Encode";
static NSString		*TrackInfoToolbarItemIdentifier				= @"org.sbooth.Max.CueSheetDocument.Toolbar.TrackInfo";
static NSString		*AlbumArtToolbarItemIdentifier				= @"org.sbooth.Max.CueSheetDocument.Toolbar.AlbumArt";
static NSString		*SelectNextTrackToolbarItemIdentifier		= @"org.sbooth.Max.CueSheetDocument.Toolbar.SelectNextTrack";
static NSString		*SelectPreviousTrackToolbarItemIdentifier	= @"org.sbooth.Max.CueSheetDocument.Toolbar.SelectPreviousTrack";
static NSString		*QueryMusicBrainzToolbarItemIdentifier		= @"org.sbooth.Max.CueSheetDocument.Toolbar.QueryMusicBrainz";

@implementation CueSheetDocumentToolbar

- (id) initWithCueSheetDocument:(CueSheetDocument *)document
{
	if((self = [super initWithIdentifier:@"org.sbooth.Max.CueSheetDocument.Toolbar"])) {
		_document = [document retain];
	}
	return self;
}

- (void) dealloc
{
	[_document release],	_document = nil;
	
	[super dealloc];
}

- (void) validateVisibleItems
{
	NSArray			*visibleItems	= [self visibleItems];
	NSToolbarItem	*item;
	NSEnumerator	*enumerator;
	
	enumerator = [visibleItems objectEnumerator];
	while((item = [enumerator nextObject])) {
		if([item action] == @selector(encode:))
			[item setEnabled:[_document encodeAllowed]];
		else if([item action] == @selector(queryMusicBrainz:))
			[item setEnabled:[_document queryMusicBrainzAllowed]];
		else
			[item setEnabled:YES];
	}
}

#pragma mark Delegate Methods

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdentifier isEqualToString:EncodeToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Convert", @"CueSheet", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Convert", @"CueSheet", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Convert the selected tracks", @"CueSheet", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"EncodeToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(encode:)];
	}
    else if([itemIdentifier isEqualToString:TrackInfoToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Metadata", @"CueSheet", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Metadata", @"CueSheet", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Show or hide detailed track metadata", @"CueSheet", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"TrackInfoToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(toggleTrackInformation:)];
	}
    else if([itemIdentifier isEqualToString:AlbumArtToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Album Art", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Album Art", @"CompactDisc", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Show or hide the artwork associated with this album", @"CompactDisc", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"AlbumArtToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(toggleAlbumArt:)];
	}
    else if([itemIdentifier isEqualToString:SelectNextTrackToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Next", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Next", @"CompactDisc", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Select the next track for editing", @"CompactDisc", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"SelectNextTrackToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(selectNextTrack:)];
	}
    else if([itemIdentifier isEqualToString:SelectPreviousTrackToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Previous", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Previous", @"CompactDisc", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Select the previous track for editing", @"CompactDisc", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"SelectPreviousTrackToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(selectPreviousTrack:)];
	}
    else if([itemIdentifier isEqualToString:QueryMusicBrainzToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Query", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Query", @"CompactDisc", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Query MusicBrainz for album information", @"CompactDisc", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"MusicBrainz"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(queryMusicBrainz:)];
	}
	else
		toolbarItem = nil;
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects:EncodeToolbarItemIdentifier, 
		TrackInfoToolbarItemIdentifier, AlbumArtToolbarItemIdentifier,
		QueryMusicBrainzToolbarItemIdentifier, 
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects:EncodeToolbarItemIdentifier,
		TrackInfoToolbarItemIdentifier, AlbumArtToolbarItemIdentifier,
		SelectPreviousTrackToolbarItemIdentifier, SelectNextTrackToolbarItemIdentifier,
		QueryMusicBrainzToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

@end
