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

#import "FileConversionToolbar.h"
#import "FileConversionController.h"

static NSString		*EncodeToolbarItemIdentifier			= @"org.sbooth.Max.FileConversion.Toolbar.Encode";
static NSString		*MetadataToolbarItemIdentifier			= @"org.sbooth.Max.FileConversion.Toolbar.Metadata";
static NSString		*AlbumArtToolbarItemIdentifier			= @"org.sbooth.Max.FileConversion.Toolbar.AlbumArt";

@implementation FileConversionToolbar

- (id) init
{
	if((self = [super initWithIdentifier:@"org.sbooth.Max.FileConversion.Toolbar"])) {
	}
	return self;
}

- (void) validateVisibleItems
{
	NSArray			*visibleItems	= [self visibleItems];
	NSEnumerator	*enumerator		= [visibleItems objectEnumerator];
	NSToolbarItem	*item;
	
	while((item = [enumerator nextObject])) {
		if([item action] == @selector(encode:))
			[item setEnabled:[[FileConversionController sharedController] encodeAllowed]];
//		if([item action] == @selector(queryMusicBrainz:))
//			[item setEnabled:[[FileConversionController sharedController] queryMusicBrainzAllowed]];
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
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Convert", @"FileConversion", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Convert", @"FileConversion", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Convert the selected files", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"EncodeToolbarImage"]];
		
		[toolbarItem setTarget:[FileConversionController sharedController]];
		[toolbarItem setAction:@selector(encode:)];
	}
	else if([itemIdentifier isEqualToString:MetadataToolbarItemIdentifier]) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Metadata", @"FileConversion", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Metadata", @"FileConversion", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Show or hide the metadata associated with the selected files", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"TrackInfoToolbarImage"]];
		
		[toolbarItem setTarget:[FileConversionController sharedController]];
		[toolbarItem setAction:@selector(toggleTrackInformation:)];
	}
	else if([itemIdentifier isEqualToString:AlbumArtToolbarItemIdentifier]) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		
		[toolbarItem setLabel: NSLocalizedStringFromTable(@"Album Art", @"FileConversion", @"")];
		[toolbarItem setPaletteLabel: NSLocalizedStringFromTable(@"Album Art", @"FileConversion", @"")];
		[toolbarItem setToolTip: NSLocalizedStringFromTable(@"Show or hide the artwork associated with the selected files", @"FileConversion", @"")];
		[toolbarItem setImage: [NSImage imageNamed:@"AlbumArtToolbarImage"]];
		
		[toolbarItem setTarget:[FileConversionController sharedController]];
		[toolbarItem setAction:@selector(toggleAlbumArt:)];
	}
	else
		toolbarItem = nil;
	
	return toolbarItem;	
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar 
{
    return [NSArray arrayWithObjects:EncodeToolbarItemIdentifier, 
			MetadataToolbarItemIdentifier, 
			AlbumArtToolbarItemIdentifier, 
			nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar 
{
    return [NSArray arrayWithObjects:EncodeToolbarItemIdentifier, 
			MetadataToolbarItemIdentifier, 
			AlbumArtToolbarItemIdentifier,
			NSToolbarSeparatorItemIdentifier, 
			NSToolbarSpaceItemIdentifier, 
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier, 
			nil];
}

@end
