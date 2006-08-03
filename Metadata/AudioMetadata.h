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

@interface AudioMetadata : NSObject
{
	unsigned				_trackNumber;
	unsigned				_trackTotal;
	NSString				*_trackTitle;
	NSString				*_trackArtist;
	NSString				*_trackComposer;
	unsigned				_trackYear;
	NSString				*_trackGenre;
	NSString				*_trackComment;

	NSString				*_albumTitle;
	NSString				*_albumArtist;
	NSString				*_albumComposer;
	unsigned				_albumYear;
	NSString				*_albumGenre;
	NSString				*_albumComment;

	BOOL					_compilation;
	unsigned				_discNumber;
	unsigned				_discTotal;

	unsigned				_length;
	
	NSImage					*_albumArt;
	
	NSString				*_MCN;
	NSString				*_ISRC;
	
	NSString				*_playlist;
}

// Attempt to parse metadata from filename
+ (AudioMetadata *)		metadataFromFile:(NSString *)filename;

// Create output file's basename
- (NSString *)			outputBasenameForDirectory:(NSString *)outputDirectory;

// Create output file's basename
- (NSString *)			outputBasenameForDirectory:(NSString *)outputDirectory withSubstitutions:(NSDictionary *)substitutions;

// Substitute our values for {} keywords in string
- (NSString *)			replaceKeywordsInString:(NSString *)namingScheme;

- (BOOL)		isEmpty;

- (unsigned)	trackNumber;
- (void)		setTrackNumber:(unsigned)trackNumber;

- (unsigned)	trackTotal;
- (void)		setTrackTotal:(unsigned)trackTotal;

- (NSString *)	trackTitle;
- (void)		setTrackTitle:(NSString *)trackTitle;

- (NSString *)	trackArtist;
- (void)		setTrackArtist:(NSString *)trackArtist;

- (NSString	*)	trackComposer;
- (void)		setTrackComposer:(NSString *)trackComposer;

- (unsigned)	trackYear;
- (void)		setTrackYear:(unsigned)trackYear;

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

- (unsigned)	albumYear;
- (void)		setAlbumYear:(unsigned)albumYear;

- (NSString	*)	albumGenre;
- (void)		setAlbumGenre:(NSString *)albumGenre;

- (NSString	*)	albumComment;
- (void)		setAlbumComment:(NSString *)albumComment;

- (BOOL)		compilation;
- (void)		setCompilation:(BOOL)compilation;

- (unsigned)	discNumber;
- (void)		setDiscNumber:(unsigned)discNumber;

- (unsigned)	discTotal;
- (void)		setDiscTotal:(unsigned)discTotal;

- (unsigned)	length;
- (void)		setLength:(unsigned)length;

- (NSString *)	MCN;
- (void)		setMCN:(NSString *)MCN;

- (NSString *)	ISRC;
- (void)		setISRC:(NSString *)ISRC;

- (NSImage *)	albumArt;
- (void)		setAlbumArt:(NSImage *)albumArt;

- (NSString *)	playlist;
- (void)		setPlaylist:(NSString *)playlist;

// Legacy support
- (unsigned)	albumTrackCount;
- (void)		setAlbumTrackCount:(unsigned)albumTrackCount;

@end
