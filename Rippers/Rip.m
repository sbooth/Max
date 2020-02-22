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

#import "Rip.h"

#include <IOKit/storage/IOCDTypes.h>

/* sha-256 a block of memory */
void sha_memory(unsigned char *buf, int len, unsigned char *hash);

@interface Rip (Private)
- (void)				setFirstSector:(NSUInteger)sector;
- (void)				setLastSector:(NSUInteger)sector;
@end

@implementation Rip

- (id) init
{
	return [self initWithFirstSector:0 lastSector:0];
}

- (id) initWithSectorRange:(SectorRange *)range
{
	return [self initWithFirstSector:[range firstSector] lastSector:[range lastSector]];
}

- (id) initWithFirstSector:(NSUInteger)firstSector lastSector:(NSUInteger)lastSector
{
	NSUInteger i;
	
	if((self = [super init])) {
		
		_sectorRange	= [[SectorRange alloc] init];

		[self setFirstSector:firstSector];
		[self setLastSector:lastSector];

		_calculateHashes	= YES;
		
		_hashes			= (unsigned char **)calloc([self length], sizeof(unsigned char *));

		if(NULL == _hashes) {
			[self release];
			return nil;
		}
		
		for(i = 0; i < [self length]; ++i) {
			_hashes[i] = NULL;
		}
		
		_filename		= nil;
		
		_errors			= [[BitArray alloc] init];
		[_errors setBitCount:[self length]];

		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	NSUInteger i;
	
	[_sectorRange release];			_sectorRange	= nil;
	[_filename release];			_filename		= nil;
	
	for(i = 0; i < [self length]; ++i) {
		free(_hashes[i]);
	}
	
	free(_hashes);					_hashes = NULL;
	
	[_errors release];				_errors = nil;
	
	[super dealloc];
}

#pragma mark SectorRange access

- (NSUInteger)		firstSector									{ return [_sectorRange firstSector]; }
- (NSUInteger)		lastSector									{ return [_sectorRange lastSector]; }

- (NSUInteger)		length										{ return [_sectorRange length]; }
- (BOOL)			containsSector:(NSUInteger)sector			{ return [_sectorRange containsSector:sector]; }
- (BOOL)			containsSectorRange:(SectorRange *)range	{ return [_sectorRange containsSectorRange:range]; }

- (void)			setFirstSector:(NSUInteger)sector			{ [_sectorRange setFirstSector:sector]; }
- (void)			setLastSector:(NSUInteger)sector			{ [_sectorRange setLastSector:sector]; }

#pragma mark -

- (NSString *)		filename									{ return _filename; }
- (void)			setFilename:(NSString *)filename			{ [_filename release]; _filename = [filename retain]; }

#pragma mark -

- (BOOL)				calculateHashes							{ return _calculateHashes; }
- (void)				setCalculateHashes:(BOOL)calculateHashes{ _calculateHashes = calculateHashes; }

#pragma mark -

- (NSUInteger)			hashLength								{ return 32; }

- (unsigned char *)		hashForSector:(NSUInteger)sector
{
/*	if(NO == [self containsSector:sector]) {
		return NULL;
	}*/
	
	return _hashes[[_sectorRange indexForSector:sector]];
}

- (BOOL)				sector:(NSUInteger)sector hasHash:(unsigned char *)hash
{
	return (0 == memcmp(hash, [self hashForSector:sector], 32/*[self hashLength]*/));
}

- (BOOL)				sector:(NSUInteger)sector matchesSector:(void *)data
{
	int8_t		buffer [ kCDSectorSizeCDDA ];
	
	[self getBytes:buffer forSector:sector];
	
	return (0 == memcmp(data, buffer, kCDSectorSizeCDDA));
}

- (NSData *)			dataForSector:(NSUInteger)sector
{
	return [self dataForSectorRange:[SectorRange sectorRangeWithSector:sector]];
}

- (NSData *)			dataForSectorRange:(SectorRange *)range
{
	NSData		*result			= nil;
	int16_t		*buffer			= NULL;

	if(NO == [self containsSectorRange:range] || nil == [self filename]) {
		return nil;
	}

	@try {
		
		// Allocate a buffer large enough to hold the desired sectors
		buffer = calloc([range length], kCDSectorSizeCDDA);
		NSAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		// Grab the data
		[self getBytes:buffer forSectorRange:range];
		
		// Package them up
		result = [NSData dataWithBytesNoCopy:buffer length:[range byteSize]];
	}
	
	@finally {		
		if(nil == result) {
			free(buffer);
		}
	}

	return (nil != result ? [[result retain] autorelease] : nil);
}

- (void)				getBytes:(void *)buffer forSector:(NSUInteger)sector
{
	[self getBytes:buffer forSectorRange:[SectorRange sectorRangeWithSector:sector]];
}

- (void)				getBytes:(void *)buffer forSectorRange:(SectorRange *)range
{
	int			fd				= -1;
	off_t		offset			= -1;
	off_t		location		= -1;
	ssize_t		bytesRead		= -1;
	
	if(NO == [self containsSectorRange:range] || nil == [self filename]) {
		return;
	}
	
	@try {
		// Zero the buffer
		bzero(buffer, [range byteSize]);
		
		// Open the file for reading
		fd = open([_filename fileSystemRepresentation], O_RDONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		NSAssert(-1 != fd, NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @""));
		
		// Seek to the offset for the first sector
		location	= kCDSectorSizeCDDA * [_sectorRange indexForSector:[range firstSector]];
		offset		= lseek(fd, location, SEEK_SET);
		NSAssert(-1 != offset, NSLocalizedStringFromTable(@"Unable to seek in the input file.", @"Exceptions", @""));
		
		// Read the sectors into the buffer
		bytesRead = read(fd, buffer, [range byteSize]);
		NSAssert(-1 != bytesRead && (NSUInteger)bytesRead == [range byteSize], NSLocalizedStringFromTable(@"Unable to read from the input file.", @"Exceptions", @""));
	}
	
	@finally {
		if(-1 != fd) {
			close(fd);
		}
	}
}

- (void)				setData:(NSData *)data forSector:(NSUInteger)sector
{
	[self setData:data forSectorRange:[SectorRange sectorRangeWithSector:sector]];
}

- (void)				setData:(NSData *)data forSectorRange:(SectorRange *)range
{
	if([range byteSize] < [data length]) {
		return;
	}
	
	[self setBytes:[data bytes] forSectorRange:range];
}

- (void)				setBytes:(const void *)buffer forSector:(NSUInteger)sector
{
	[self setBytes:buffer forSectorRange:[SectorRange sectorRangeWithSector:sector]];
}

- (void)				setBytes:(const void *)buffer forSectorRange:(SectorRange *)range
{
	int				fd				= -1;
	off_t			location		= -1;
	off_t			offset			= -1;
	ssize_t			bytesWritten	= -1;
	NSUInteger		i				= 0;
	NSUInteger		arrayIndex		= 0;
	uint8_t			sector			[ kCDSectorSizeCDDA ];
	unsigned char	hash			[ 32 ];
	
	if(NO == [self containsSectorRange:range]  || nil == [self filename]) {
		return;
	}
	
	@try {
		
		// Open the file for writing
		fd = open([_filename fileSystemRepresentation], O_WRONLY | O_APPEND, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		NSAssert(-1 != fd, NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @""));
		
		// Seek to the offset for the first sector
		location	= kCDSectorSizeCDDA * [_sectorRange indexForSector:[range firstSector]];
		offset		= lseek(fd, location, SEEK_SET);
		NSAssert(-1 != offset, NSLocalizedStringFromTable(@"Unable to seek in the input file.", @"Exceptions", @""));
		
		// Write the sectors into the file
		bytesWritten = write(fd, buffer, [range byteSize]);
		NSAssert(-1 != bytesWritten && (NSUInteger)bytesWritten == [range byteSize], NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
		
		if(NO == [self calculateHashes]) {
			return;
		}
		
		// Compute the hash value for each sector and store them
		for(i = 0; i < [range length]; ++i) {
			arrayIndex = [_sectorRange indexForSector:[range firstSector] + i];
			
			// Extract the sector's bytes
			memcpy(sector, buffer + (kCDSectorSizeCDDA * i), kCDSectorSizeCDDA);
			
			// Compute the SHA-256 for the sector
			sha_memory(sector, kCDSectorSizeCDDA, hash);
			
			// Allocate space for the hash
			_hashes[arrayIndex] = calloc(32, sizeof(unsigned char));
			NSAssert(NULL != _hashes[arrayIndex], NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
			
			// Copy the hash value
			memcpy(_hashes[arrayIndex], hash, 32 * sizeof(unsigned char));
		}
	}
	
	@finally {
		if(-1 != fd) {
			close(fd);
		}
	}
}

#pragma mark -

- (BOOL)				sectorHasError:(NSUInteger)sector
{
	return [_errors valueAtIndex:(sector - [self firstSector])];
}

- (void)				setErrorFlag:(BOOL)errorFlag forSector:(NSUInteger)sector
{
	[_errors setValue:errorFlag forIndex:(sector - [self firstSector])];
}

- (void)				setErrorFlags:(const void *)errorFlags forSectorRange:(SectorRange *)range
{
	const uint32_t	*flags;
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i, j;
	
	flags			= (const uint32_t *)errorFlags;
	lastArrayIndex	= [range length] / (8 * sizeof(uint32_t));
	lastBitIndex	= [range length] % (8 * sizeof(uint32_t));
	
	for(i = 0; i < lastArrayIndex; ++i) {
		if(flags[i]) {
			for(j = 0; j < 8; ++j) {
				if(flags[i] & (1 << j)) {
					[_errors setValue:YES forIndex:([range firstSector] + ((8 * sizeof(uint32_t) * i) + j) - [self firstSector])];
				}
			}
		}
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		if(flags[lastArrayIndex] & (1 << i)) {
			[_errors setValue:YES forIndex:([range firstSector] + ((8 * sizeof(uint32_t) * lastArrayIndex) + i) - [self firstSector])];
		}
	}
}

@end
