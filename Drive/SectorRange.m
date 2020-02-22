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

#import "SectorRange.h"

#include <IOKit/storage/IOCDTypes.h>

@implementation SectorRange

+ (id) sectorRangeWithFirstSector:(NSUInteger)firstSector lastSector:(NSUInteger)lastSector
{
	NSParameterAssert(lastSector >= firstSector);
	
	SectorRange *range = [[SectorRange alloc] init];
	
	[range setFirstSector:firstSector];
	[range setLastSector:lastSector];
	
	return [range autorelease];
}

+ (id) sectorRangeWithFirstSector:(NSUInteger)firstSector sectorCount:(NSUInteger)sectorCount
{
	NSParameterAssert(0 < sectorCount);

	SectorRange *range = [[SectorRange alloc] init];
	
	[range setFirstSector:firstSector];
	[range setLastSector:firstSector + sectorCount - 1];
	
	return [range autorelease];
}

+ (id) sectorRangeWithSector:(NSUInteger)sector
{
	SectorRange *range = [[SectorRange alloc] init];
	
	[range setFirstSector:sector];
	[range setLastSector:sector];
	
	return [range autorelease];
}

- (NSUInteger)		firstSector										{ return _firstSector; }
- (void)			setFirstSector:(NSUInteger)sector				{ _firstSector = sector; }

- (NSUInteger)		lastSector										{ return _lastSector; }
- (void)			setLastSector:(NSUInteger)sector				{ _lastSector = sector; }

- (NSUInteger)		length											{ return ([self lastSector] - [self firstSector] + 1); }
- (NSUInteger)		byteSize										{ return kCDSectorSizeCDDA * [self length]; }

- (NSUInteger)		indexForSector:(NSUInteger)sector				{ return ([self containsSector:sector] ? sector - [self firstSector] : NSNotFound); }
- (NSUInteger)		sectorForIndex:(NSUInteger)idx					{ return ([self length] > idx ? [self firstSector] + idx : NSNotFound); }

- (BOOL)			containsSector:(NSUInteger)sector				{ return ([self firstSector] <= sector && [self lastSector] >= sector); }
- (BOOL)			containsSectorRange:(SectorRange *)range		{ return ([self containsSector:[range firstSector]] && [self containsSector:[range lastSector]]); }

@end
