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

#import <Cocoa/Cocoa.h>

#import "AlbumArtMethods.h"

enum {
	kAmazonLocaleUSMenuItemTag			= 1,
	kAmazonLocaleFRMenuItemTag			= 2,
	kAmazonLocaleCAMenuItemTag			= 3,
	kAmazonLocaleDEMenuItemTag			= 4,
	kAmazonLocaleUKMenuItemTag			= 5,
	kAmazonLocaleJAMenuItemTag			= 6
};

@interface AmazonAlbumArtSheet : NSObject
{
    IBOutlet NSWindow			*_sheet;
    IBOutlet NSTableView		*_table;
    IBOutlet NSTextField		*_artistTextField;
    IBOutlet NSTextField		*_titleTextField;
    IBOutlet NSPopUpButton		*_localePopUpButton;
	
	NSMutableArray				*_images;
	id <AlbumArtMethods>		_source;
	NSNumber					*_searchInProgress;
}

- (id)				initWithSource:(id <AlbumArtMethods>)source;

- (void)			showAlbumArtMatches;

- (IBAction)		search:(id)sender;
- (IBAction)		cancel:(id)sender;

- (IBAction)		useSelected:(id)sender;
- (IBAction)		visitAmazon:(id)sender;

@end
