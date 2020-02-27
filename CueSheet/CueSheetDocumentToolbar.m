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

#import "CueSheetDocumentToolbar.h"

static NSString		*EncodeToolbarItemIdentifier				= @"org.sbooth.Max.CueSheetDocument.Toolbar.Encode";
static NSString		*MetadataToolbarItemIdentifier				= @"org.sbooth.Max.CueSheetDocument.Toolbar.Metadata";
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
	[_document release];
	_document = nil;
	
	[super dealloc];
}

- (void) validateVisibleItems
{
	NSArray			*visibleItems	= [self visibleItems];
	NSToolbarItem	*item;
	
	for(item in visibleItems) {
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
    else if([itemIdentifier isEqualToString:MetadataToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Metadata", @"CueSheet", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Metadata", @"CueSheet", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Show or hide detailed track metadata", @"CueSheet", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"NSInfo"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(toggleMetadataInspectorPanel:)];
	}
    else if([itemIdentifier isEqualToString:SelectNextTrackToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Next", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Next", @"CompactDisc", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Select the next track for editing", @"CompactDisc", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"NSGoRightTemplate"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(selectNextTrack:)];
	}
    else if([itemIdentifier isEqualToString:SelectPreviousTrackToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel:NSLocalizedStringFromTable(@"Previous", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel:NSLocalizedStringFromTable(@"Previous", @"CompactDisc", @"")];
		[toolbarItem setToolTip:NSLocalizedStringFromTable(@"Select the previous track for editing", @"CompactDisc", @"")];
		[toolbarItem setImage:[NSImage imageNamed:@"NSGoLeftTemplate"]];
		
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
		MetadataToolbarItemIdentifier,
		QueryMusicBrainzToolbarItemIdentifier, 
		nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects:EncodeToolbarItemIdentifier,
		MetadataToolbarItemIdentifier,
		SelectPreviousTrackToolbarItemIdentifier, SelectNextTrackToolbarItemIdentifier,
		QueryMusicBrainzToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

@end
