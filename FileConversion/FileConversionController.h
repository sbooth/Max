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

#import "FileArrayController.h"
#import "AlbumArtMethods.h"

@interface FileConversionController : NSWindowController <AlbumArtMethods>
{
	IBOutlet NSArrayController		*_encodersController;
	IBOutlet FileArrayController	*_filesController;
	IBOutlet NSDrawer				*_metadataDrawer;
	IBOutlet NSDrawer				*_artDrawer;
	IBOutlet NSTableView			*_filesTableView;
	
	NSMutableArray					*_files;
}

+ (FileConversionController *)		sharedController;

- (NSArray *)						genres;

- (IBAction)						convert:(id)sender;

- (IBAction)						addFiles:(id)sender;
- (IBAction)						removeFiles:(id)sender;

- (IBAction)						downloadAlbumArt:(id)sender;
- (IBAction)						selectAlbumArt:(id)sender;

- (IBAction)						setupEncoders:(id)sender;

- (BOOL)							addFile:(NSString *)filename;
- (BOOL)							addFile:(NSString *)filename atIndex:(unsigned)index;

@end
