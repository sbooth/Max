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

#import "FreeDBProtocolValueTransformer.h"

#include <cddb/cddb.h>

@implementation FreeDBProtocolValueTransformer

+ (Class)	transformedValueClass			{ return [NSString class]; }
+ (BOOL)	allowsReverseTransformation		{ return YES; }

- (id) transformedValue:(id) value;
{
	if(nil == value) {
		return nil;		
	}
	
	if(NO == [value isKindOfClass:[NSNumber class]]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Value was not NSNumber." userInfo:nil];
	}
	
	switch([(NSNumber *)value intValue]) {
		case PROTO_CDDBP:			return @"CDDBP";			// break;
		case PROTO_HTTP:			return @"HTTP";				// break;
		case PROTO_UNKNOWN:			return @"Unknown";			// break;
		default:					return @"";					// break;
	}
}

- (id) reverseTransformedValue:(id) value;
{	
	if(nil == value) {
		return nil;		
	}
	
	if(NO == [value isKindOfClass:[NSString class]]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Value was not NSString." userInfo:nil];
	}
	
	if([(NSString *)value isEqualToString:@"CDDBP"]) {
		return [NSNumber numberWithInt:PROTO_CDDBP];
	}
	else if([(NSString *)value isEqualToString:@"HTTP"]) {
		return [NSNumber numberWithInt:PROTO_HTTP];
	}
	else if([(NSString *)value isEqualToString:@"Unknown"]) {
		return [NSNumber numberWithInt:PROTO_UNKNOWN];
	}
	else {
		return [NSNumber numberWithInt:-1];		
	}
}

@end
