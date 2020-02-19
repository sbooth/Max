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

#import "SecondsFormatter.h"

@implementation SecondsFormatter

- (NSString *) stringForObjectValue:(id)object
{
	NSString		*result			= nil;
	unsigned		value;
	unsigned		hours			= 0;
	unsigned		minutes			= 0;
	unsigned		seconds			= 0;
	
	
	if(nil == object || NO == [object isKindOfClass:[NSNumber class]]) {
		return nil;
	}
	
	value		= [object unsignedIntValue];
	
	if(UINT_MAX == value) {
		return nil;
	}
	
	seconds		= value % 60;
	minutes		= value / 60;
	
	while(60 <= minutes) {
		minutes -= 60;
		++hours;
	}

	if(0 < hours) {
		result = [NSString stringWithFormat:@"%u:%u:%.2u", hours, minutes, seconds];
	}
	else if(0 < minutes) {
		result = [NSString stringWithFormat:@"%u:%.2u", minutes, seconds];
	}
	else {
		result = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%u seconds", @"General", @""), seconds];
	}
	
	return [[result retain] autorelease];
}

- (BOOL) getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString  **)error
{
	NSScanner		*scanner		= nil;
	BOOL			result			= NO;
	int				value			= 0;
	unsigned		seconds			= 0;

	scanner		= [NSScanner scannerWithString:string];
	
	while(NO == [scanner isAtEnd]) {
		
		// Grab a value
		if([scanner scanInt:&value]) {
			seconds		*= 60;
			seconds		+= value;
			result		= YES;
		}
		
		// Grab the separator, if present
		[scanner scanString:@":" intoString:NULL];
	}
	
	if(result && NULL != object) {
		*object = [NSNumber numberWithUnsignedInt:seconds];
	}
	else if(NULL != error) {
		*error = @"Couldn't convert to seconds";
	}
	
	return result;
}

- (NSAttributedString *) attributedStringForObjectValue:(id)object withDefaultAttributes:(NSDictionary *)attributes
{
	NSString				*stringValue	= nil;
	NSAttributedString		*result			= nil;
	NSMutableDictionary		*newAttributes	= nil;
	
	stringValue		= [self stringForObjectValue:object];
	newAttributes	= [attributes mutableCopy];
	
	if(nil == stringValue) {
		stringValue		= NSLocalizedStringFromTable(@"Queued", @"General", @"");
		[newAttributes setObject:[[NSColor blackColor] colorWithAlphaComponent:0.6] forKey:NSForegroundColorAttributeName];
	}
	
	result			= [[NSAttributedString alloc] initWithString:stringValue attributes:[newAttributes autorelease]];
		
	return [result autorelease];
}

@end
