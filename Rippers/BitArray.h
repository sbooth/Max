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

@interface BitArray : NSObject
{
	unsigned		_bitCount;
	unsigned		_length;
	uint32_t		*_bits;
}

// Access the number of bits this object holds
- (unsigned)		bitCount;
- (void)			setBitCount:(unsigned)bitCount;

// Access to the individual bits
- (BOOL)			valueAtIndex:(unsigned)index;
- (void)			setValue:(BOOL)value forIndex:(unsigned)index;

// Convenience methods
- (BOOL)			allZeroes;
- (unsigned)		countOfZeroes;
- (void)			setAllZeroes;

- (BOOL)			allOnes;
- (unsigned)		countOfOnes;
- (void)			setAllOnes;

@end
