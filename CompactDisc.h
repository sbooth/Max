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

#import "CDDrive.h"
#import "Track.h"

#include "cddb/cddb_disc.h"


@interface CompactDisc : NSObject 
{
	// Related data structures
	CDDrive				*_drive;
	cddb_disc_t			*_cddb_disc;
	
	// ID3 tags
	NSString			*_title;			// TALB
	NSString			*_artist;			// TPE1
	NSNumber			*_year;				// TYER
	NSNumber			*_genre;			// TCON
	NSString			*_comment;			// COMM
	
	NSNumber			*_partOfSet;		// TPOS

	// Other disc info
	NSNumber			*_discNumber;
	NSNumber			*_discsInSet;
	NSNumber			*_multiArtist;
	
	unsigned			_length;

	// Array of audio tracks
	NSMutableArray		*_tracks;
}

- (id) initWithBSDName:(NSString *) bsdName;

- (unsigned long)	cddb_id;
- (cddb_disc_t *)	cddb_disc;
- (NSString *)		length;

- (NSArray *)		selectedTracks;

// Save/Restore
- (NSDictionary *) getDictionary;
- (void) setPropertiesFromDictionary:(NSDictionary *)properties;

@end
