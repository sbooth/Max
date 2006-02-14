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

#import <Cocoa/Cocoa.h>

#import "CompactDisc.h"
#import "Track.h"


@interface CompactDiscDocument : NSDocument 
{
    IBOutlet NSArrayController		*_trackController;
    IBOutlet NSDrawer				*_trackDrawer;
    IBOutlet NSDrawer				*_artDrawer;
    IBOutlet NSTableView			*_trackTable;

	CompactDisc						*_disc;
	NSNumber						*_discInDrive;
	NSNumber						*_discID;
	NSNumber						*_freeDBQueryInProgress;
	NSNumber						*_freeDBQuerySuccessful;
		
	// Disc information
	NSString						*_title;
	NSString						*_artist;
	NSNumber						*_year;
	NSString						*_genre;
	NSString						*_comment;
	NSNumber						*_partOfSet;
	NSImage							*_albumArt;

	// Other disc info
	NSNumber						*_discNumber;
	NSNumber						*_discsInSet;
	NSNumber						*_multiArtist;
	
	NSString						*_MCN;
	
	// Array of audio tracks
	NSMutableArray					*_tracks;
}

- (NSArray *)		genres;
- (void)			displayException:(NSException *)exception;

- (NSArray *)		tracks;
- (NSArray *)		selectedTracks;

// Toolbar/menu item enabling utility methods
- (BOOL)			encodeAllowed;
- (BOOL)			queryFreeDBAllowed;
- (BOOL)			submitToFreeDBAllowed;
- (BOOL)			ejectDiscAllowed;

- (BOOL)			emptySelection;
- (BOOL)			ripInProgress;
- (BOOL)			encodeInProgress;

// Action methods
- (IBAction)		selectAll:(id) sender;
- (IBAction)		selectNone:(id) sender;
- (IBAction)		encode:(id) sender;
- (IBAction)		ejectDisc:(id) sender;
- (IBAction)		queryFreeDB:(id) sender;
- (IBAction)		submitToFreeDB:(id) sender;
- (IBAction)		toggleTrackInformation:(id) sender;
- (IBAction)		toggleAlbumArt:(id) sender;
- (IBAction)		selectNextTrack:(id) sender;
- (IBAction)		selectPreviousTrack:(id) sender;
- (IBAction)		fetchAlbumArt:(id) sender;
- (IBAction)		selectAlbumArt:(id) sender;
- (IBAction)		albumArtUpdated:(id) sender;

- (void)			clearFreeDBData;
- (void)			updateDiscFromFreeDB:(NSDictionary *) info;

- (int)				discID;

- (BOOL)			discInDrive;
- (void)			discEjected;

- (CompactDisc *)	getDisc;
- (void)			setDisc:(CompactDisc *)disc;

// Save/Restore
- (NSDictionary *)	getDictionary;
- (void)			setPropertiesFromDictionary:(NSDictionary *)properties;

@end
