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

#import <Cocoa/Cocoa.h>

#import "FileArrayController.h"

@interface FileConversionController : NSWindowController
{
	IBOutlet FileArrayController	*_filesController;
	IBOutlet NSPanel				*_metadataPanel;
	IBOutlet NSTableView			*_filesTableView;
	IBOutlet NSTextField			*_trackNumberTextField;
	IBOutlet NSTextField			*_trackTotalTextField;
	IBOutlet NSTextField			*_discNumberTextField;
	IBOutlet NSTextField			*_discTotalTextField;
	
	NSMutableArray					*_files;
}

+ (FileConversionController *)		sharedController;

- (NSArray *)						genres;

- (BOOL)							encodeAllowed;
- (IBAction)						encode:(id)sender;

- (IBAction)						toggleMetadataInspectorPanel:(id)sender;

- (IBAction)						addFiles:(id)sender;
- (IBAction)						removeFiles:(id)sender;

- (IBAction)						downloadAlbumArt:(id)sender;
- (IBAction)						selectAlbumArt:(id)sender;

- (BOOL)							addFile:(NSString *)filename;
- (BOOL)							addFile:(NSString *)filename atIndex:(NSUInteger)index;

@end
