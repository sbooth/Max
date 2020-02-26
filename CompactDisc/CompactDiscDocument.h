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

#import "CompactDisc.h"
#import "Track.h"

enum {
	kEncodeMenuItemTag					= 1,
	kTrackInfoMenuItemTag				= 2,
	kQueryMusicBrainzMenuItemTag		= 3,
	kEjectDiscMenuItemTag				= 4,
	kSelectNextTrackMenuItemTag			= 6,
	kSelectPreviousTrackMenuItemTag		= 7,
	kDownloadAlbumArtMenuItemTag		= 8
};

@interface CompactDiscDocument : NSDocument
{
    IBOutlet NSArrayController		*_trackController;
	IBOutlet NSPanel				*_metadataPanel;
    IBOutlet NSTableView			*_trackTable;
	IBOutlet NSTextField			*_discNumberTextField;
	IBOutlet NSTextField			*_discTotalTextField;

	CompactDisc						*_disc;
	BOOL							_discInDrive;
	NSString						*_discID;
	
	BOOL							_ejectRequested;
	
	// Disc information
	NSString						*_title;
	NSString						*_artist;
	NSString						*_date;
	NSString						*_genre;
	NSString						*_composer;
	NSString						*_comment;

	// MusicBrainz identifiers
	NSString						*_musicbrainzAlbumId;
	NSString						*_musicbrainzArtistId;
	
	NSImage							*_albumArt;

	// Other disc info
	NSNumber						*_discNumber;
	NSNumber 						*_discTotal;
	NSNumber						*_compilation;
	
	NSString						*_MCN;
	
	// Array of audio tracks
	NSMutableArray					*_tracks;
}

- (NSArray *)		genres;

// State
- (BOOL)			encodeAllowed;
- (BOOL)			queryMusicBrainzAllowed;
- (BOOL)			ejectDiscAllowed;
- (BOOL)			submitDiscIdAllowed;

- (BOOL)			emptySelection;
- (BOOL)			ripInProgress;
- (BOOL)			encodeInProgress;

// Action methods
- (IBAction)		selectAll:(id)sender;
- (IBAction)		selectNone:(id)sender;

- (IBAction)		encode:(id)sender;

- (IBAction)		ejectDisc:(id)sender;

- (IBAction)		submitDiscId:(id)sender;

- (IBAction)		queryMusicBrainz:(id)sender;
- (void)			queryMusicBrainzNonInteractive;

- (IBAction)		toggleMetadataInspectorPanel:(id)sender;

- (IBAction)		selectNextTrack:(id)sender;
- (IBAction)		selectPreviousTrack:(id)sender;

- (IBAction)		downloadAlbumArt:(id)sender;
- (IBAction)		selectAlbumArt:(id)sender;

// Miscellaneous
- (BOOL)			ejectRequested;
- (void)			setEjectRequested:(BOOL)ejectRequested;

- (void)			discEjected;

- (NSArray *)		selectedTracks;

- (CompactDisc *)	disc;
- (void)			setDisc:(CompactDisc *)disc;

- (BOOL)			discInDrive;
- (void)			setDiscInDrive:(BOOL)discInDrive;

- (NSString *)		discID;
- (void)			setDiscID:(NSString *)discID;

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

- (NSString *)		musicbrainzArtistId;
- (void)			setMusicbrainzArtistId:(NSString *)musicbrainzArtistId;

- (NSString *)		musicbrainzAlbumId;
- (void)			setMusicbrainzAlbumId:(NSString *)musicbrainzAlbumId;

// KVC methods
- (NSUInteger)		countOfTracks;
- (Track *)			objectInTracksAtIndex:(NSUInteger)index;

- (void)			insertObject:(Track *)track inTracksAtIndex:(NSUInteger)index;
- (void)			removeObjectFromTracksAtIndex:(NSUInteger)index;

@end

@interface CompactDiscDocument (ScriptingAdditions)
- (instancetype) handleEncodeScriptCommand:(NSScriptCommand *)command;
- (instancetype) handleEjectDiscScriptCommand:(NSScriptCommand *)command;
- (instancetype) handleQueryMusicBrainzScriptCommand:(NSScriptCommand *)command;
- (instancetype) handleToggleInspectorPanelScriptCommand:(NSScriptCommand *)command;
@end
