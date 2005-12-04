/*
 *  $Id: CompactDisc.h 122 2005-11-18 21:57:28Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

static NSString		*EncodeToolbarItemIdentifier			= @"Encode";
static NSString		*TrackInfoToolbarItemIdentifier			= @"TrackInfo";
static NSString		*QueryFreeDBToolbarItemIdentifier		= @"QueryFreeDB";
static NSString		*EjectDiscToolbarItemIdentifier			= @"EjectDisc";

#define kEncodeToolbarItemTag		0
#define kTrackInfoToolbarItemTag	1
#define kQueryFreeDBToolbarItemTag	2
#define kEjectDiscToolbarItemTag	3

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
			default:
				[item setEnabled:YES];
				break;
			case kEncodeToolbarItemTag:
				[item setEnabled:[_document encodeAllowed]];
				break;
			case kQueryFreeDBToolbarItemTag:
				[item setEnabled:[_document queryFreeDBAllowed]];
				break;
			case kEjectDiscToolbarItemTag:
				[item setEnabled:[_document ejectDiscAllowed]];
				break;
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
		[toolbarItem setLabel: @"Encode"];
		[toolbarItem setPaletteLabel: @"Encode"];		
		[toolbarItem setToolTip: @"Encode the selected tracks"];
		[toolbarItem setImage: [NSImage imageNamed:@"EncodeToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(encode:)];
	}
    else if([itemIdentifier isEqualToString:TrackInfoToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kTrackInfoToolbarItemTag];
		[toolbarItem setLabel: @"Tracks"];
		[toolbarItem setPaletteLabel: @"Tracks"];
		[toolbarItem setToolTip: @"Show or hide detailed track information"];
		[toolbarItem setImage: [NSImage imageNamed:@"TrackInfoToolbarImage"]];
		
		[toolbarItem setTarget:[_document valueForKey:@"trackDrawer"]];
		[toolbarItem setAction:@selector(toggle:)];
	}
    else if([itemIdentifier isEqualToString:QueryFreeDBToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kQueryFreeDBToolbarItemTag];
		[toolbarItem setLabel: @"Query FreeDB"];
		[toolbarItem setPaletteLabel: @"Query FreeDB"];
		[toolbarItem setToolTip: @"Query FreeDB for album information"];
		[toolbarItem setImage: [NSImage imageNamed:@"FreeDBToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(queryFreeDB:)];
	}
    else if([itemIdentifier isEqualToString:EjectDiscToolbarItemIdentifier]) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setTag:kEjectDiscToolbarItemTag];
		[toolbarItem setLabel: @"Eject"];
		[toolbarItem setPaletteLabel: @"Eject"];
		[toolbarItem setToolTip: @"Eject the CD"];
		[toolbarItem setImage: [NSImage imageNamed:@"EjectDiscToolbarImage"]];
		
		[toolbarItem setTarget:_document];
		[toolbarItem setAction:@selector(eject:)];
	}
	else {
		toolbarItem = nil;
    }
	
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects: EncodeToolbarItemIdentifier, TrackInfoToolbarItemIdentifier, 
		QueryFreeDBToolbarItemIdentifier, NSToolbarSpaceItemIdentifier, EjectDiscToolbarItemIdentifier, 
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects: EncodeToolbarItemIdentifier, TrackInfoToolbarItemIdentifier,
		QueryFreeDBToolbarItemIdentifier, EjectDiscToolbarItemIdentifier, 
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

@end
