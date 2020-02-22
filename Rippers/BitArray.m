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

#import "BitArray.h"

@implementation BitArray

- (void) dealloc
{
	free(_bits);			_bits = NULL;
	[super dealloc];
}

#pragma mark Bit Count

- (NSUInteger)		bitCount									{ return _bitCount; }
- (void)			setBitCount:(NSUInteger)bitCount
{
	_bitCount	= bitCount;
	_length		= ([self bitCount] / (8 * sizeof(NSUInteger))) + 1;
	
	free(_bits);
	_bits = calloc(_length, sizeof(NSUInteger));
	NSAssert(NULL != _bits, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
}

#pragma mark Bit Setting

- (BOOL)				valueAtIndex:(NSUInteger)idx
{
	NSUInteger		arrayIndex;
	NSUInteger		bitIndex;

	arrayIndex	= idx / (8 * sizeof(NSUInteger));
	bitIndex	= idx % (8 * sizeof(NSUInteger));
	
	return (_bits[arrayIndex] & (1 << bitIndex) ? YES : NO);
}

- (void)				setValue:(BOOL)value forIndex:(NSUInteger)idx
{
	NSUInteger		arrayIndex;
	NSUInteger		bitIndex;
	NSUInteger		mask;
	
	arrayIndex	= idx / (8 * sizeof(NSUInteger));
	bitIndex	= idx % (8 * sizeof(NSUInteger));
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
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(NSUInteger));
	lastBitIndex	= [self bitCount] % (8 * sizeof(NSUInteger));
	
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

- (NSUInteger)		countOfZeroes
{
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i, j;
	NSUInteger		result;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(NSUInteger));
	lastBitIndex	= [self bitCount] % (8 * sizeof(NSUInteger));
	result			= 0;
	
	for(i = 0; i < lastArrayIndex; ++i) {
		for(j = 0; j < (8 * sizeof(NSUInteger)); ++j) {
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
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(NSUInteger));
	lastBitIndex	= [self bitCount] % (8 * sizeof(NSUInteger));
	
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
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(NSUInteger));
	lastBitIndex	= [self bitCount] % (8 * sizeof(NSUInteger));
	
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

- (NSUInteger)		countOfOnes
{
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i, j;
	NSUInteger		result;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(NSUInteger));
	lastBitIndex	= [self bitCount] % (8 * sizeof(NSUInteger));
	result			= 0;
	
	for(i = 0; i < lastArrayIndex; ++i) {
		for(j = 0; j < (8 * sizeof(NSUInteger)); ++j) {
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
	NSUInteger		lastArrayIndex;
	NSUInteger		lastBitIndex;
	NSUInteger		i;
	
	lastArrayIndex	= [self bitCount] / (8 * sizeof(NSUInteger));
	lastBitIndex	= [self bitCount] % (8 * sizeof(NSUInteger));
	
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
	NSUInteger			i;
	
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
