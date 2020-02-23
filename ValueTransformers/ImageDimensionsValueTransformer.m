/*
 *  Copyright (C) 2020 Stephen F. Booth <me@sbooth.org>
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

#import "ImageDimensionsValueTransformer.h"

@implementation ImageDimensionsValueTransformer

+ (Class)	transformedValueClass			{ return [NSString class]; }
+ (BOOL)	allowsReverseTransformation		{ return NO; }

- (id) transformedValue:(id) value;
{
	if(nil == value) {
		return nil;
	}

	if(![value isKindOfClass:[NSImage class]]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Value was not NSImage." userInfo:nil];
	}

	return [NSString stringWithFormat:@"%lu × %lu", (unsigned long)[value size].width, (unsigned long)[value size].height];
}

@end
