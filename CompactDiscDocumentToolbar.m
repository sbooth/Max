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

#import "CompactDiscDocumentToolbar.h"

static NSString		*EncodeToolbarItemIdentifier				= @"Encode";
static NSString		*TrackInfoToolbarItemIdentifier				= @"TrackInfo";
static NSString		*SelectNextTrackToolbarItemIdentifier		= @"SelectNextTrack";
static NSString		*SelectPreviousTrackToolbarItemIdentifier	= @"SelectPreviousTrack";
static NSString		*QueryFreeDBToolbarItemIdentifier			= @"QueryFreeDB";
static NSString		*SubmitToFreeDBToolbarItemIdentifier		= @"SubmitToFreeDB";
static NSString		*EjectDiscToolbarItemIdentifier				= @"EjectDisc";

#define kEncodeToolbarItemTag					1
#define kTrackInfoToolbarItemTag				2
#define kQueryFreeDBToolbarItemTag				3
#define kSubmitToFreeDBToolbarItemTag			4
#define kEjectDiscToolbarItemTag				5
#define kSelectNextTrackToolbarItemTag			6
#define kSelectPreviousTrackToolbarItemTag		7

@implementation CompactDiscDocumentToolbar

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)document
{
	if((self = [super initWithIdentifier:@"Max CompactDiscDocumentToolbar"])) {
		_document = [document retain];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_document release];
	[super dealloc];
}

- (void) validateVisibleItems
{
	NSArray			*visibleItems	= [self visibleItems];
	NSEnumerator	*enumerator		= [visibleItems objectEnumerator];
	NSToolbarItem	*item;
	
	while((item = [enumerator nextObject])) {
		switch([item tag]) {
			default:							[item setEnabled:YES];									break;
			case kEncodeToolbarItemTag:			[item setEnabled:[_document encodeAllowed]];			break;
			case kQueryFreeDBToolbarItemTag:	[item setEnabled:[_document queryFreeDBAllowed]];		break;
			case kSubmitToFreeDBToolbarItemTag:	[item setEnabled:[_document submitToFreeDBAllowed]];	break;
			case kEjectDiscToolbarItemTag:		[item setEnabled:[_document ejectDiscAllowed]];			break;
		}
	}
}

#pragma mark Delegate Methods

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag 
{
    NSToolbarItem *toolbarItem = nil;
    
    if([itemIdentifier isEqualToString:EncodeToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kEncodeToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Encode", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Encode", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Encode the selected tracks", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"EncodeToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(encode:)];
	}
    else if([itemIdentifier isEqualToString:TrackInfoToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kTrackInfoToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Tracks", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Tracks", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Show or hide detailed track information", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"TrackInfoToolbarImage"]];
		
		[toolbarItem setTarget:[_document valueForKey:@"trackDrawer"]];
		[toolbarItem setAction:@selector(toggle:)];
	}
    else if([itemIdentifier isEqualToString:SelectNextTrackToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kSelectNextTrackToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Next", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Next", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Select the next track for editing", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"SelectNextTrackToolbarImage"]];
		
		[toolbarItem setTarget:[_document valueForKey:@"trackController"]];
		[toolbarItem setAction:@selector(selectNext:)];
	}
    else if([itemIdentifier isEqualToString:SelectPreviousTrackToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kSelectPreviousTrackToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Previous", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Previous", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Select the previous track for editing", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"SelectPreviousTrackToolbarImage"]];
		
		[toolbarItem setTarget:[_document valueForKey:@"trackController"]];
		[toolbarItem setAction:@selector(selectPrevious:)];
	}
    else if([itemIdentifier isEqualToString:QueryFreeDBToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kQueryFreeDBToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Query FreeDB", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Query FreeDB", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Query FreeDB for album information", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"FreeDBToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(queryFreeDB:)];
	}
    else if([itemIdentifier isEqualToString:SubmitToFreeDBToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kSubmitToFreeDBToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Submit", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Submit", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Submit album information to FreeDB", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"SubmitToFreeDBToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(submitToFreeDB:)];
	}
    else if([itemIdentifier isEqualToString:EjectDiscToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kEjectDiscToolbarItemTag];
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Eject", @"CompactDisc", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Eject", @"CompactDisc", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Eject the CD", @"CompactDisc", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"EjectDiscToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(ejectDisc:)];
	}
	else {
		toolbarItem = nil;
    }
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects: EncodeToolbarItemIdentifier, TrackInfoToolbarItemIdentifier, 
		QueryFreeDBToolbarItemIdentifier,
		NSToolbarSpaceItemIdentifier, EjectDiscToolbarItemIdentifier, 
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: EncodeToolbarItemIdentifier, 
		SelectPreviousTrackToolbarItemIdentifier, TrackInfoToolbarItemIdentifier, SelectNextTrackToolbarItemIdentifier,
		QueryFreeDBToolbarItemIdentifier, SubmitToFreeDBToolbarItemIdentifier,
		EjectDiscToolbarItemIdentifier, 
		NSToolbarSeparatorItemIdentifier,  NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier, nil];
}

@end
