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

#import "CueSheetTrack.h"

@interface CueSheetDocument : NSDocument
{
    IBOutlet NSArrayController		*_trackController;
	IBOutlet NSPanel				*_metadataPanel;
    IBOutlet NSTableView			*_trackTable;
	IBOutlet NSTextField			*_discNumberTextField;
	IBOutlet NSTextField			*_discTotalTextField;

	// Disc information
	NSString						*_title;
	NSString						*_artist;
	NSString						*_date;
	NSString						*_genre;
	NSString						*_composer;
	NSString						*_comment;
	
	NSImage							*_albumArt;
	
	// Other disc info
	NSNumber						*_discNumber;
	NSNumber						*_discTotal;
	NSNumber						*_compilation;
	
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

- (IBAction)		toggleMetadataInspectorPanel:(id)sender;

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

- (NSNumber *)		discNumber;
- (void)			setDiscNumber:(NSNumber *)discNumber;

- (NSNumber *)		discTotal;
- (void)			setDiscTotal:(NSNumber *)discTotal;

- (NSNumber *)		compilation;
- (void)			setCompilation:(NSNumber *)compilation;

- (NSString *)		MCN;
- (void)			setMCN:(NSString *)MCN;

// Calculate a MusicBrainz disc ID for this cue sheet
- (NSString *) discID;

	// KVC methods
- (NSUInteger)		countOfTracks;
- (CueSheetTrack *)	objectInTracksAtIndex:(NSUInteger)index;

- (void)			insertObject:(CueSheetTrack *)track inTracksAtIndex:(NSUInteger)index;
- (void)			removeObjectFromTracksAtIndex:(NSUInteger)index;

@end
