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

#import "BitArray.h"

@implementation BitArray

- (void) dealloc
{
	free(_bits);			_bits = NULL;
	[super dealloc];
}

#pragma mark Bit Count

- (unsigned)		bitCount									{ return _bitCount; }
- (void)			setBitCount:(unsigned)bitCount
{
	_bitCount	= bitCount;
	_length		= ([self bitCount] / (8 * sizeof(uint32_t))) + 1;
	
	free(_bits);
	_bits = calloc(_length, sizeof(uint32_t));
	NSAssert(NULL != _bits, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
}

#pragma mark Bit Setting

- (BOOL)				valueAtIndex:(unsigned)idx
{
	unsigned		arrayIndex;
	unsigned		bitIndex;

	arrayIndex	= idx / (8 * sizeof(uint32_t));
	bitIndex	= idx % (8 * sizeof(uint32_t));
	
	return (_bits[arrayIndex] & (1 << bitIndex) ? YES : NO);
}

- (void)				setValue:(BOOL)value forIndex:(unsigned)idx
{
	unsigned		arrayIndex;
	unsigned		bitIndex;
	uint32_t		mask;
	
	arrayIndex	= idx / (8 * sizeof(uint32_t));
	bitIndex	= idx % (8 * sizeof(uint32_t));
	mask		= value << bitIndex;
	
	if(value) {
		_bits[arrayIndex] |= mask;
	}
	else {
		_bits[arrayIndex] &= mask;
	}
}

#pragma mark Zero methods

- (BOOL)			allZeroes
{
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(uint32_t));
	lastBitIndex	= [self bitCount] % (8 * sizeof(uint32_t));
	
	for(i = 0; i < lastArrayIndex; ++i) {
		if(0x00000000 != _bits[i]) {
			return NO;
		}
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		if(0 != (_bits[lastArrayIndex] & (1 << i))) {
			return NO;
		}
	}
	
	return YES;
}

- (unsigned)		countOfZeroes
{
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i, j;
	unsigned		result;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(uint32_t));
	lastBitIndex	= [self bitCount] % (8 * sizeof(uint32_t));
	result			= 0;
	
	for(i = 0; i < lastArrayIndex; ++i) {
		for(j = 0; j < (8 * sizeof(uint32_t)); ++j) {
			if(!(_bits[i] & (1 << j))) {
				++result;
			}
		}
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		if(!(_bits[lastArrayIndex] & (1 << i))) {
			++result;
		}
	}
	
	return result;
}

- (void)			setAllZeroes
{
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(uint32_t));
	lastBitIndex	= [self bitCount] % (8 * sizeof(uint32_t));
	
	for(i = 0; i < lastArrayIndex; ++i) {
		_bits[i] = 0x00000000;
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		_bits[lastArrayIndex] &= ~(1 << i);
	}
}

#pragma mark One methods

- (BOOL)			allOnes
{
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(uint32_t));
	lastBitIndex	= [self bitCount] % (8 * sizeof(uint32_t));
	
	for(i = 0; i < lastArrayIndex; ++i) {
		if(0xFFFFFFFF != _bits[i]) {
			return NO;
		}
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		if(0 == (_bits[lastArrayIndex] & (1 << i))) {
			return NO;
		}
	}
	
	return YES;
}

- (unsigned)		countOfOnes
{
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i, j;
	unsigned		result;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(uint32_t));
	lastBitIndex	= [self bitCount] % (8 * sizeof(uint32_t));
	result			= 0;
	
	for(i = 0; i < lastArrayIndex; ++i) {
		for(j = 0; j < (8 * sizeof(uint32_t)); ++j) {
			if(_bits[i] & (1 << j)) {
				++result;
			}
		}
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		if(_bits[lastArrayIndex] & (1 << i)) {
			++result;
		}
	}
	
	return result;
}

- (void)			setAllOnes
{
	unsigned		lastArrayIndex;
	unsigned		lastBitIndex;
	unsigned		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(uint32_t));
	lastBitIndex	= [self bitCount] % (8 * sizeof(uint32_t));
	
	for(i = 0; i < lastArrayIndex; ++i) {
		_bits[i] = 0xFFFFFFFF;
	}
	
	for(i = 0; i < lastBitIndex; ++i) {
		_bits[lastArrayIndex] |= 1 << i;
	}
}

- (NSString *)		description
{
	NSMutableString		*result;
	unsigned			i;
	
	result = [NSMutableString stringWithCapacity:[self bitCount]];
	for(i = 0; i < [self bitCount]; ++i) {
		[result appendString:([self valueAtIndex:i] ? @"1" : @"0")];
		if(0 == i % 8) {
			[result appendString:@" "];
		}
		if(0 == i % 32) {
			[result appendString:@"\n"];
		}
	}
	
	return result;
}

@end
