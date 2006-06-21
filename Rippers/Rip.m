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

#import "Rip.h"
#import "MallocException.h"
#import "IOException.h"

#include <IOKit/storage/IOCDTypes.h>

@interface Rip (Private)
- (void)				setFirstSector:(unsigned)sector;
- (void)				setLastSector:(unsigned)sector;
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

- (id) initWithFirstSector:(unsigned)firstSector lastSector:(unsigned)lastSector
{
	unsigned i;
	
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
	unsigned i;
	
	[_sectorRange release];			_sectorRange	= nil;
	[_filename release];			_filename		= nil;
	
	for(i = 0; i < [self length]; ++i) {
		free(_hashes[i]);
	}
	
	free(_hashes);
	
	[_errors release];
	
	[super dealloc];
}

#pragma SectorRange access

- (unsigned)		firstSector									{ return [_sectorRange firstSector]; }
- (unsigned)		lastSector									{ return [_sectorRange lastSector]; }

- (unsigned)		length										{ return [_sectorRange length]; }
- (BOOL)			containsSector:(unsigned)sector				{ return [_sectorRange containsSector:sector]; }
- (BOOL)			containsSectorRange:(SectorRange *)range	{ return [_sectorRange containsSectorRange:range]; }

- (void)			setFirstSector:(unsigned)sector				{ [_sectorRange setFirstSector:sector]; }
- (void)			setLastSector:(unsigned)sector				{ [_sectorRange setLastSector:sector]; }

#pragma mark -

- (NSString *)		filename									{ return _filename; }
- (void)			setFilename:(NSString *)filename			{ [_filename release]; _filename = [filename retain]; }

#pragma mark -

- (BOOL)				calculateHashes							{ return _calculateHashes; }
- (void)				setCalculateHashes:(BOOL)calculateHashes{ _calculateHashes = calculateHashes; }

#pragma mark -

- (unsigned)			hashLength								{ return 32; }

- (unsigned char *)		hashForSector:(unsigned)sector
{
/*	if(NO == [self containsSector:sector]) {
		return NULL;
	}*/
	
	return _hashes[[_sectorRange indexForSector:sector]];
}

- (BOOL)				sector:(unsigned)sector hasHash:(unsigned char *)hash
{
	return (0 == memcmp(hash, [self hashForSector:sector], 32/*[self hashLength]*/));
}

- (BOOL)				sector:(unsigned)sector matchesSector:(void *)data
{
	int8_t		buffer [ kCDSectorSizeCDDA ];
	
	[self getBytes:buffer forSector:sector];
	
	return (0 == memcmp(data, buffer, kCDSectorSizeCDDA));
}

- (NSData *)			dataForSector:(unsigned)sector
{
	return [self dataForSectorRange:[SectorRange rangeWithSector:sector]];
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
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

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

- (void)				getBytes:(void *)buffer forSector:(unsigned)sector
{
	[self getBytes:buffer forSectorRange:[SectorRange rangeWithSector:sector]];
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
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Seek to the offset for the first sector
		location	= kCDSectorSizeCDDA * [_sectorRange indexForSector:[range firstSector]];
		offset		= lseek(fd, location, SEEK_SET);
		if(-1 == offset/* || offset != location*/) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to seek in the input file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Read the sectors into the buffer
		bytesRead = read(fd, buffer, [range byteSize]);
		if(-1 == bytesRead || (unsigned)bytesRead != [range byteSize]) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the input file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
	
	@finally {
		if(-1 != fd) {
			close(fd);
		}
	}
}

- (void)				setData:(NSData *)data forSector:(unsigned)sector
{
	[self setData:data forSectorRange:[SectorRange rangeWithSector:sector]];
}

- (void)				setData:(NSData *)data forSectorRange:(SectorRange *)range
{
	if([range byteSize] < [data length]) {
		return;
	}
	
	[self setBytes:[data bytes] forSectorRange:range];
}

- (void)				setBytes:(const void *)buffer forSector:(unsigned)sector
{
	[self setBytes:buffer forSectorRange:[SectorRange rangeWithSector:sector]];
}

- (void)				setBytes:(const void *)buffer forSectorRange:(SectorRange *)range
{
	int				fd				= -1;
	off_t			location		= -1;
	off_t			offset			= -1;
	ssize_t			bytesWritten	= -1;
	unsigned		i				= 0;
	unsigned		arrayIndex		= 0;
	int8_t			sector			[ kCDSectorSizeCDDA ];
	unsigned char	hash			[ 32 ];
	
	if(NO == [self containsSectorRange:range]  || nil == [self filename]) {
		return;
	}
	
	@try {
		
		// Open the file for writing
		fd = open([_filename fileSystemRepresentation], O_WRONLY | O_APPEND, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Seek to the offset for the first sector
		location	= kCDSectorSizeCDDA * [_sectorRange indexForSector:[range firstSector]];
		offset		= lseek(fd, location, SEEK_SET);
		if(-1 == offset/* || offset != location*/) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to seek in the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Write the sectors into the file
		bytesWritten = write(fd, buffer, [range byteSize]);
		if(-1 == bytesWritten || (unsigned)bytesWritten != [range byteSize]) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
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
			if(NULL == _hashes[arrayIndex]) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];				
			}
			
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

- (BOOL)				sectorHasError:(unsigned)sector
{
	return [_errors valueAtIndex:(sector - [self firstSector])];
}

- (void)				setErrorFlag:(BOOL)errorFlag forSector:(unsigned)sector
{
	[_errors setValue:errorFlag forIndex:(sector - [self firstSector])];
}

- (void)				setErrorFlags:(const void *)errorFlags forSectorRange:(SectorRange *)range
{
	const uint32_t	*flags;
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i, j;
	
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
