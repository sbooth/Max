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

#import <Cocoa/Cocoa.h>

@interface SectorRange : NSObject 
{
	NSUInteger	_firstSector;
	NSUInteger	_lastSector;
}

+ (id)				sectorRangeWithFirstSector:(NSUInteger)firstSector lastSector:(NSUInteger)lastSector;
+ (id)				sectorRangeWithFirstSector:(NSUInteger)firstSector sectorCount:(NSUInteger)sectorCount;
+ (id)				sectorRangeWithSector:(NSUInteger)sector;

- (NSUInteger)		firstSector;
- (void)			setFirstSector:(NSUInteger)sector;

- (NSUInteger)		lastSector;
- (void)			setLastSector:(NSUInteger)sector;

- (NSUInteger)		length;
- (NSUInteger)		byteSize;

- (NSUInteger)		indexForSector:(NSUInteger)sector;
- (NSUInteger)		sectorForIndex:(NSUInteger)index;

- (BOOL)			containsSector:(NSUInteger)sector;
- (BOOL)			containsSectorRange:(SectorRange *)range;

@end
