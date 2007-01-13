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

#import "SectorRange.h"
#import "TrackDescriptor.h"
#import "SessionDescriptor.h"

enum {
	kCDSectorSizeQSubchannel		= 16,
	kCDSectorSizeErrorFlags			= 294
};

@interface Drive : NSObject
{
	NSString		*_deviceName;
	int				_fd;
	
	unsigned		_cacheSize;
	
	NSMutableArray	*_sessions;
	NSMutableArray	*_tracks;
	
	unsigned		_firstSession;
	unsigned		_lastSession;
}

// Set up to read the drive corresponding to deviceName (will open the device and read the CDTOC)
- (id)					initWithDeviceName:(NSString *)deviceName;

// Device management
- (BOOL)				deviceOpen;
- (void)				openDevice;
- (void)				closeDevice;

// Disc session information
- (unsigned)			firstSession;
- (unsigned)			lastSession;

- (SessionDescriptor *)	sessionNumber:(unsigned)number;

- (unsigned)			firstTrackForSession:(unsigned)session;
- (unsigned)			lastTrackForSession:(unsigned)session;

// Session sector information
- (unsigned)			firstSectorForSession:(unsigned)session;
- (unsigned)			lastSectorForSession:(unsigned)session;

- (unsigned)			leadOutForSession:(unsigned)session;

- (unsigned)			sessionContainingSector:(unsigned)sector;
- (unsigned)			sessionContainingSectorRange:(SectorRange *)sectorRange;

// Disc track information
- (TrackDescriptor *)	trackNumber:(unsigned)number;

// Track sector information
- (unsigned)			firstSectorForTrack:(unsigned)number;
- (unsigned)			lastSectorForTrack:(unsigned)number;

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

// Read a chunk of CD-DA data (buffer should be kCDSectorSizeCDDA * sectorCount bytes)
- (unsigned)			readAudio:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readAudio:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readAudio:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Read Q sub-channel (buffer should be kCDSectorSizeQSubchannel * sectorCount bytes)
- (unsigned)			readQSubchannel:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readQSubchannel:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readQSubchannel:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Read error flags (buffer should be kCDSectorSizeErrorFlags * sectorCount bytes)
- (unsigned)			readErrorFlags:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readErrorFlags:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readErrorFlags:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Read a chunk of CD-DA data, with Q sub-channel (buffer should be (kCDSectorSizeCDDA + kCDSectorSizeQSubchannel) * sectorCount bytes)
- (unsigned)			readAudioAndQSubchannel:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readAudioAndQSubchannel:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readAudioAndQSubchannel:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Read a chunk of CD-DA data, with error flags (buffer should be (kCDSectorSizeCDDA + kCDSectorSizeErrorFlags) * sectorCount bytes)
- (unsigned)			readAudioAndErrorFlags:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readAudioAndErrorFlags:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readAudioAndErrorFlags:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Read a chunk of CD-DA data, with error flags and Q sub-channel (buffer should be (kCDSectorSizeCDDA + kCDSectorSizeErrorFlags + kCDSectorSizeQSubchannel) * sectorCount bytes)
- (unsigned)			readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sector:(unsigned)sector;
- (unsigned)			readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sectorRange:(SectorRange *)range;
- (unsigned)			readAudioAndErrorFlagsWithQSubchannel:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;

// Get the CD's media catalog number
- (NSString *)			readMCN;

// Get the ISRC for the specified track
- (NSString *)			readISRC:(unsigned)track;

@end
