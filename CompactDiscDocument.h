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
	BOOL							_discInDrive;
	int								_discID;
	BOOL							_freeDBQueryInProgress;
	BOOL							_freeDBQuerySuccessful;
		
	// Disc information
	NSString						*_title;
	NSString						*_artist;
	unsigned						_year;
	NSString						*_genre;
	NSString						*_composer;
	NSString						*_comment;
	BOOL							_partOfSet;

	NSImage							*_albumArt;

	// Other disc info
	unsigned						_discNumber;
	unsigned						_discTotal;
	BOOL							_compilation;
	
	NSString						*_MCN;
	
	// Array of audio tracks
	NSMutableArray					*_tracks;
}

- (NSArray *)		genres;
- (void)			displayException:(NSException *)exception;

// State
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

// FreeDB
- (void)			clearFreeDBData;
- (void)			updateDiscFromFreeDB:(NSDictionary *) info;

// Miscellaneous
- (void)			discEjected;
- (NSArray *)		selectedTracks;

// Accessors
- (CompactDisc *)	disc;
- (BOOL)			discInDrive;
- (int)				discID;
- (BOOL)			freeDBQueryInProgress;
- (BOOL)			freeDBQuerySuccessful;

- (NSString *)		title;
- (NSString *)		artist;
- (unsigned)		year;
- (NSString *)		genre;
- (NSString *)		composer;
- (NSString *)		comment;
- (BOOL)			partOfSet;

- (NSImage *)		albumArt;
- (unsigned)		albumArtWidth;
- (unsigned)		albumArtHeight;

- (unsigned)		discNumber;
- (unsigned)		discTotal;
- (BOOL)			compilation;

- (NSString *)		MCN;

- (unsigned)		countOfTracks;
- (Track *)			objectInTracksAtIndex:(unsigned)index;

// Mutators
- (void) setDisc:(CompactDisc *)disc;
- (void) setDiscInDrive:(BOOL)discInDrive;
- (void) setDiscID:(int)discID;
- (void) setFreeDBQueryInProgress:(BOOL)freeDBQueryInProgress;
- (void) setFreeDBQuerySuccessful:(BOOL)freeDBQuerySuccessful;

- (void) setTitle:(NSString *)title;
- (void) setArtist:(NSString *)artist;
- (void) setYear:(unsigned)year;
- (void) setGenre:(NSString *)genre;
- (void) setComposer:(NSString *)composer;
- (void) setComment:(NSString *)comment;
- (void) setPartOfSet:(BOOL)partOfSet;

- (void) setAlbumArt:(NSImage *)albumArt;

- (void) setDiscNumber:(unsigned)discNumber;
- (void) setDiscTotal:(unsigned)discTotal;
- (void) setCompilation:(BOOL)compilation;

- (void) setMCN:(NSString *)MCN;

- (void) insertObject:(Track *)track inTracksAtIndex:(unsigned)index;
- (void) removeObjectFromTracksAtIndex:(unsigned)index;

@end
