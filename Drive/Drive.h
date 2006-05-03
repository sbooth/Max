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

#import "SectorRange.h"
#import "TrackDescriptor.h"

#include <IOKit/storage/IOCDTypes.h>

@interface Drive : NSObject
{
	NSString		*_deviceName;
	int				_fd;
	unsigned		_cacheSize;
	
	NSMutableArray	*_tracks;
	
	unsigned		_leadOut;
	unsigned		_firstSession;
	unsigned		_lastSession;
	unsigned		_firstTrack;
	unsigned		_lastTrack;
}

// Set up to read the drive corresponding to deviceName
- (id)					initWithDeviceName:(NSString *)deviceName;

// Disc track information
- (unsigned)			countOfTracks;
- (TrackDescriptor *)	trackNumber:(unsigned)number;

- (unsigned)			leadOut;

- (unsigned)			firstTrack;
- (unsigned)			lastTrack;

// Disc sector information
- (unsigned)			firstSector;
- (unsigned)			lastSector;

// Track sector information
- (unsigned)			firstSectorForTrack:(unsigned)number;
- (unsigned)			lastSectorForTrack:(unsigned)number;

// Disc session information
- (unsigned)			firstSession;
- (unsigned)			lastSession;

// Device name
- (NSString *)			deviceName;

// Drive cache information
- (unsigned)			cacheSize;
- (unsigned)			cacheSectorSize;
- (void)				setCacheSize:(unsigned)cacheSize;

// Drive speed
- (uint16_t)			speed;
- (void)				setSpeed:(uint16_t)speed;

// Clear the drive's cache by filling with sectors outside of range
- (void)				clearCache:(SectorRange *)range;

// Read a chunk of CD-DA data
- (unsigned)			readAudio:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readAudio:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readAudio:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Get the CD's media catalog number
- (NSString *)			readMCN;

// Get the ISRC for the specified track
- (NSString *)			readISRC:(unsigned)track;

@end
