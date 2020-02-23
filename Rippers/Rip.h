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
#import "BitArray.h"

@interface Rip : NSObject
{
	NSString			*_filename;			// The file containing the ripped CD-DA data
	SectorRange			*_sectorRange;		// The range of sectors contained in the file
	BitArray			*_errors;			// C2 error flags for the ripped sectors
	BOOL				_calculateHashes;	// Whether to calculate the SHA-256 for each sector
	unsigned char		**_hashes;			// The SHA-256 for each sector in the file
}

- (instancetype)		initWithSectorRange:(SectorRange *)range;
- (instancetype)		initWithFirstSector:(NSUInteger)firstSector lastSector:(NSUInteger)lastSector;

// Easy access to the SectorRange contained in this rip
- (NSUInteger)			firstSector;
- (NSUInteger)			lastSector;

- (NSUInteger)			length;
- (BOOL)				containsSector:(NSUInteger)sector;
- (BOOL)				containsSectorRange:(SectorRange *)range;

// Access to the filename
// Note: A Rip neither creates nor destroys the file it is associated with
- (NSString *)			filename;
- (void)				setFilename:(NSString *)filename;

// Specify if the SHA-256 should be calculated for each sector
- (BOOL)				calculateHashes;
- (void)				setCalculateHashes:(BOOL)calculateHashes;

// Access to the hashes for each sector
- (NSUInteger)			hashLength;
- (unsigned char *)		hashForSector:(NSUInteger)sector;

// Sector equality testing
- (BOOL)				sector:(NSUInteger)sector hasHash:(unsigned char *)hash;
- (BOOL)				sector:(NSUInteger)sector matchesSector:(void *)data;

// Access the CD-DA data for a specific sector range
- (NSData *)			dataForSector:(NSUInteger)sector;
- (NSData *)			dataForSectorRange:(SectorRange *)range;

- (void)				getBytes:(void *)buffer forSector:(NSUInteger)sector;
- (void)				getBytes:(void *)buffer forSectorRange:(SectorRange *)range;

- (void)				setData:(NSData *)data forSector:(NSUInteger)sector;
- (void)				setData:(NSData *)data forSectorRange:(SectorRange *)range;

- (void)				setBytes:(const void *)data forSector:(NSUInteger)sector;
- (void)				setBytes:(const void *)data forSectorRange:(SectorRange *)range;

// Error flag manipulation
- (BOOL)				sectorHasError:(NSUInteger)sector;

- (void)				setErrorFlag:(BOOL)errorFlag forSector:(NSUInteger)sector;
- (void)				setErrorFlags:(const void *)errorFlags forSectorRange:(SectorRange *)range;

@end
