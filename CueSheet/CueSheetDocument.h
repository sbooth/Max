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

#import "CueSheetTrack.h"

@interface CueSheetDocument : NSDocument
{
    IBOutlet NSArrayController		*_trackController;
    IBOutlet NSDrawer				*_trackDrawer;
    IBOutlet NSDrawer				*_artDrawer;
    IBOutlet NSTableView			*_trackTable;

	// Disc information
	NSString						*_title;
	NSString						*_artist;
	NSString						*_date;
	NSString						*_genre;
	NSString						*_composer;
	NSString						*_comment;
	
	NSImage							*_albumArt;
	
	NSDate							*_albumArtDownloadDate;
	
	// Other disc info
	NSNumber						*_discNumber;
	NSNumber						*_discTotal;
	BOOL							_compilation;
	
	NSString						*_MCN;
	
	// Array of audio tracks
	NSMutableArray					*_tracks;
}

- (NSArray *)		genres;

// State
- (BOOL)			encodeAllowed;
- (BOOL)			queryMusicBrainzAllowed;

- (BOOL)			emptySelection;

// Action methods
- (IBAction)		selectAll:(id)sender;
- (IBAction)		selectNone:(id)sender;

- (IBAction)		encode:(id)sender;

- (IBAction)		queryMusicBrainz:(id)sender;
- (void)			queryMusicBrainzNonInteractive;

- (IBAction)		toggleTrackInformation:(id)sender;
- (IBAction)		toggleAlbumArt:(id)sender;

- (IBAction)		selectNextTrack:(id)sender;
- (IBAction)		selectPreviousTrack:(id)sender;

- (IBAction)		downloadAlbumArt:(id)sender;
- (IBAction)		selectAlbumArt:(id)sender;

// Miscellaneous
- (NSArray *)		selectedTracks;

// Metadata
- (NSString *)		title;
- (void)			setTitle:(NSString *)title;

- (NSString *)		artist;
- (void)			setArtist:(NSString *)artist;

- (NSString *)		date;
- (void)			setDate:(NSString *)date;

- (NSString *)		genre;
- (void)			setGenre:(NSString *)genre;

- (NSString *)		composer;
- (void)			setComposer:(NSString *)composer;

- (NSString *)		comment;
- (void)			setComment:(NSString *)comment;

- (NSImage *)		albumArt;
- (void)			setAlbumArt:(NSImage *)albumArt;

- (NSDate *)		albumArtDownloadDate;
- (void)			setAlbumArtDownloadDate:(NSDate *)albumArtDownloadDate;

- (unsigned)		albumArtWidth;
- (unsigned)		albumArtHeight;

- (NSNumber *)		discNumber;
- (void)			setDiscNumber:(NSNumber *)discNumber;

- (NSNumber *)		discTotal;
- (void)			setDiscTotal:(NSNumber *)discTotal;

- (BOOL)			compilation;
- (void)			setCompilation:(BOOL)compilation;

- (NSString *)		MCN;
- (void)			setMCN:(NSString *)MCN;

	// KVC methods
- (unsigned)		countOfTracks;
- (CueSheetTrack *)	objectInTracksAtIndex:(unsigned)index;

- (void)			insertObject:(CueSheetTrack *)track inTracksAtIndex:(unsigned)index;
- (void)			removeObjectFromTracksAtIndex:(unsigned)index;

@end
