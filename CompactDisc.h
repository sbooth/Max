/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "Track.h"

@interface CompactDisc : NSObject 
{
	// io_object
	NSNumber			*_io_object;
	
	// ID3 tags
	NSString			*_title;			// TALB
	NSString			*_artist;			// TPE1
	NSNumber			*_year;				// TYER
	NSNumber			*_genre;			// TCON
	NSString			*_comment;			// COMM
	
	NSNumber			*_partOfSet;		// TPOS

	NSNumber			*_discNumber;
	NSNumber			*_discsInSet;
	
	NSNumber			*_multiArtist;

	// Array of all actual audio tracks (no leadin or TOC data)
	NSMutableArray		*_tracks;
	
	NSString			*_bsdPath;
	NSNumber			*_preferredBlockSize;
	
	Track				*_leadOut;
	NSNumber			*_type;
	NSNumber			*_firstTrack;
	NSNumber			*_lastTrack;
}

+ (CompactDisc *) createFromIOObject:(io_object_t)disc;

- (unsigned long) cddb_id;

- (NSNumber *) getDuration;

- (NSArray *) selectedTracks;

- (NSDictionary *) getDictionary;
- (void) setPropertiesFromDictionary:(NSDictionary *)properties;

// ========== Private Methods - DO NOT USE
- (void) addTrack:(Track *)track;
@end
