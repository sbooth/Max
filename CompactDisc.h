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

#include <cdparanoia/cdda_interface.h>
#include <cddb/cddb_disc.h>

@interface CompactDisc : NSObject
{
	NSString			*_bsdName;
	NSString			*_deviceName;

	NSMutableArray		*_tracks;
	NSString			*_MCN;
	NSNumber			*_firstSector;
	NSNumber			*_lastSector;
	
	cddb_disc_t			*_freeDBDisc;
	unsigned			_length;
}

- (id)					initWithBSDName:(NSString *)bsdName;

- (NSString *)			bsdName;
- (NSString *)			deviceName;

// Physical disc properties
- (unsigned)			trackCount;

- (unsigned long)		firstSector;
- (unsigned long)		lastSector;

- (NSString *)			MCN;

- (unsigned long)		firstSectorForTrack:(unsigned) track;
- (unsigned long)		lastSectorForTrack:(unsigned) track;

- (unsigned)			channelsForTrack:(unsigned) track;

- (BOOL)				trackContainsAudio:(unsigned) track;
- (BOOL)				trackHasPreEmphasis:(unsigned) track;
- (BOOL)				trackAllowsDigitalCopy:(unsigned) track;

- (NSString *)			ISRC:(unsigned) track;

// KVC accessors
- (unsigned int)		countOfTracks;
- (NSDictionary *)		objectInTracksAtIndex:(unsigned int)index;

// Derived properties
- (int)					discID;
- (unsigned)			length;

- (cddb_disc_t *)		getFreeDBDisc;

@end
