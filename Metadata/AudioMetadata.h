/*
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

@interface AudioMetadata : NSObject
{
	NSNumber				*_trackNumber;
	NSNumber				*_trackTotal;
	NSString				*_trackTitle;
	NSString				*_trackArtist;
	NSString				*_trackComposer;
	NSString				*_trackDate;
	NSString				*_trackGenre;
	NSString				*_trackComment;

	NSString				*_albumTitle;
	NSString				*_albumArtist;
	NSString				*_albumComposer;
	NSString				*_albumDate;
	NSString				*_albumGenre;
	NSString				*_albumComment;

	NSNumber				*_compilation;
	NSNumber				*_discNumber;
	NSNumber				*_discTotal;

	NSNumber				*_length;
	
	NSImage					*_albumArt;
	
	NSString				*_discId;
	NSString				*_MCN;
	NSString				*_ISRC;
	
	NSString				*_musicbrainzTrackId;
	NSString				*_musicbrainzArtistId;
	NSString				*_musicbrainzAlbumId;
	NSString				*_musicbrainzAlbumArtistId;
	
	NSString				*_playlist;
}

// Attempt to parse metadata from filename
+ (AudioMetadata *)		metadataFromFile:(NSString *)filename;

// Substitute our values for {} keywords in string
- (NSString *)			replaceKeywordsInString:(NSString *)namingScheme;

- (BOOL)		isEmpty;

- (NSNumber *)	trackNumber;
- (void)		setTrackNumber:(NSNumber *)trackNumber;

- (NSNumber *)	trackTotal;
- (void)		setTrackTotal:(NSNumber *)trackTotal;

- (NSString *)	trackTitle;
- (void)		setTrackTitle:(NSString *)trackTitle;

- (NSString *)	trackArtist;
- (void)		setTrackArtist:(NSString *)trackArtist;

- (NSString	*)	trackComposer;
- (void)		setTrackComposer:(NSString *)trackComposer;

- (NSString *)	trackDate;
- (void)		setTrackDate:(NSString *)trackDate;

- (NSString	*)	trackGenre;
- (void)		setTrackGenre:(NSString *)trackGenre;

- (NSString	*)	trackComment;
- (void)		setTrackComment:(NSString *)trackComment;

- (NSString	*)	albumTitle;
- (void)		setAlbumTitle:(NSString *)albumTitle;

- (NSString	*)	albumArtist;
- (void)		setAlbumArtist:(NSString *)albumArtist;

- (NSString	*)	albumComposer;
- (void)		setAlbumComposer:(NSString *)albumComposer;

- (NSString *)	albumDate;
- (void)		setAlbumDate:(NSString *)albumDate;

- (NSString	*)	albumGenre;
- (void)		setAlbumGenre:(NSString *)albumGenre;

- (NSString	*)	albumComment;
- (void)		setAlbumComment:(NSString *)albumComment;

- (NSNumber *)	compilation;
- (void)		setCompilation:(NSNumber *)compilation;

- (NSNumber *)	discNumber;
- (void)		setDiscNumber:(NSNumber *)discNumber;

- (NSNumber *)	discTotal;
- (void)		setDiscTotal:(NSNumber *)discTotal;

- (NSNumber *)	length;
- (void)		setLength:(NSNumber *)length;

- (NSString *)	discId;
- (void)		setDiscId:(NSString *)discId;

- (NSString *)	MCN;
- (void)		setMCN:(NSString *)MCN;

- (NSString *)	ISRC;
- (void)		setISRC:(NSString *)ISRC;

- (NSString *)	musicbrainzTrackId;
- (void)		setMusicbrainzTrackId:(NSString *)musicbrainzTrackId;

- (NSString *)	musicbrainzArtistId;
- (void)		setMusicbrainzArtistId:(NSString *)musicbrainzArtistId;

- (NSString *)	musicbrainzAlbumId;
- (void)		setMusicbrainzAlbumId:(NSString *)musicbrainzAlbumId;

- (NSString *)	musicbrainzAlbumArtistId;
- (void)		setMusicbrainzAlbumArtistId:(NSString *)musicbrainzAlbumArtistId;

- (NSImage *)	albumArt;
- (void)		setAlbumArt:(NSImage *)albumArt;

- (NSString *)	playlist;
- (void)		setPlaylist:(NSString *)playlist;

@end
