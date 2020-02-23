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
	
	NSUInteger		_cacheSize;
	
	NSMutableArray	*_sessions;
	NSMutableArray	*_tracks;
	
	NSUInteger		_firstSession;
	NSUInteger		_lastSession;
}

// Set up to read the drive corresponding to deviceName (will open the device and read the CDTOC)
- (instancetype)		initWithDeviceName:(NSString *)deviceName;

// Device management
- (BOOL)				deviceOpen;
- (void)				openDevice;
- (void)				closeDevice;

// Disc session information
- (NSUInteger)			firstSession;
- (NSUInteger)			lastSession;

- (SessionDescriptor *)	sessionNumber:(NSUInteger)number;

- (NSUInteger)			firstTrackForSession:(NSUInteger)session;
- (NSUInteger)			lastTrackForSession:(NSUInteger)session;

// Session sector information
- (NSUInteger)			firstSectorForSession:(NSUInteger)session;
- (NSUInteger)			lastSectorForSession:(NSUInteger)session;

- (NSUInteger)			leadOutForSession:(NSUInteger)session;

- (NSUInteger)			sessionContainingSector:(NSUInteger)sector;
- (NSUInteger)			sessionContainingSectorRange:(SectorRange *)sectorRange;

// Disc track information
- (TrackDescriptor *)	trackNumber:(NSUInteger)number;

// Track sector information
- (NSUInteger)			firstSectorForTrack:(NSUInteger)number;
- (NSUInteger)			lastSectorForTrack:(NSUInteger)number;

// Device name
- (NSString *)			deviceName;

// Drive cache information
- (NSUInteger)			cacheSize;
- (NSUInteger)			cacheSectorSize;
- (void)				setCacheSize:(NSUInteger)cacheSize;

// Drive speed
- (uint16_t)			speed;
- (void)				setSpeed:(uint16_t)speed;

// Clear the drive's cache by filling with sectors outside of range
- (void)				clearCache:(SectorRange *)range;

// Read a chunk of CD-DA data (buffer should be kCDSectorSizeCDDA * sectorCount bytes)
- (NSUInteger)			readAudio:(void *)buffer sector:(NSUInteger)sector;
- (NSUInteger)			readAudio:(void *)buffer sectorRange:(SectorRange *)range;
- (NSUInteger)			readAudio:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;

// Read Q sub-channel (buffer should be kCDSectorSizeQSubchannel * sectorCount bytes)
- (NSUInteger)			readQSubchannel:(void *)buffer sector:(NSUInteger)sector;
- (NSUInteger)			readQSubchannel:(void *)buffer sectorRange:(SectorRange *)range;
- (NSUInteger)			readQSubchannel:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;

// Read error flags (buffer should be kCDSectorSizeErrorFlags * sectorCount bytes)
- (NSUInteger)			readErrorFlags:(void *)buffer sector:(NSUInteger)sector;
- (NSUInteger)			readErrorFlags:(void *)buffer sectorRange:(SectorRange *)range;
- (NSUInteger)			readErrorFlags:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;

// Read a chunk of CD-DA data, with Q sub-channel (buffer should be (kCDSectorSizeCDDA + kCDSectorSizeQSubchannel) * sectorCount bytes)
- (NSUInteger)			readAudioAndQSubchannel:(void *)buffer sector:(NSUInteger)sector;
- (NSUInteger)			readAudioAndQSubchannel:(void *)buffer sectorRange:(SectorRange *)range;
- (NSUInteger)			readAudioAndQSubchannel:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;

// Read a chunk of CD-DA data, with error flags (buffer should be (kCDSectorSizeCDDA + kCDSectorSizeErrorFlags) * sectorCount bytes)
- (NSUInteger)			readAudioAndErrorFlags:(void *)buffer sector:(NSUInteger)sector;
- (NSUInteger)			readAudioAndErrorFlags:(void *)buffer sectorRange:(SectorRange *)range;
- (NSUInteger)			readAudioAndErrorFlags:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;

// Read a chunk of CD-DA data, with error flags and Q sub-channel (buffer should be (kCDSectorSizeCDDA + kCDSectorSizeErrorFlags + kCDSectorSizeQSubchannel) * sectorCount bytes)
- (NSUInteger)			readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sector:(NSUInteger)sector;
- (NSUInteger)			readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sectorRange:(SectorRange *)range;
- (NSUInteger)			readAudioAndErrorFlagsWithQSubchannel:(void *)buffer startSector:(NSUInteger)startSector sectorCount:(NSUInteger)sectorCount;

// Get the CD's media catalog number
- (NSString *)			readMCN;

// Get the ISRC for the specified track
- (NSString *)			readISRC:(NSUInteger)track;

@end
