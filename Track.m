/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "Track.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include <IOKit/storage/IOCDTypes.h>

@implementation Track

+ (void)initialize 
{
	NSString				*trackDefaultsValuesPath;
    NSDictionary			*trackDefaultsValuesDictionary;
    
	@try {
		trackDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"TrackDefaults" ofType:@"plist"];
		if(nil == trackDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load TrackDefaults.plist" userInfo:nil];
		}
		trackDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:trackDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:trackDefaultsValuesDictionary];
		
		[self setKeys:[NSArray arrayWithObjects:@"artist", @"year", @"genre", nil] triggerChangeNotificationsForDependentKey:@"color"];
		[self setKeys:[NSArray arrayWithObjects:@"minute", @"second", @"frame", nil] triggerChangeNotificationsForDependentKey:@"firstSector"];
		[self setKeys:[NSArray arrayWithObjects:@"lastSector", @"firstSector", nil] triggerChangeNotificationsForDependentKey:@"size"];
		[self setKeys:[NSArray arrayWithObjects:@"lastSector", @"firstSector", nil] triggerChangeNotificationsForDependentKey:@"length"];
		[self setKeys:[NSArray arrayWithObjects:@"lastSector", @"firstSector", nil] triggerChangeNotificationsForDependentKey:@"duration"];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (NSString *) getType
{
	switch([_type intValue]) {
		case 0x00: return @"2ch audio, no pre-emphasis, digital copy prohibited";
		case 0x01: return @"2ch audio, with pre-emphasis, digital copy prohibited";
		case 0x02: return @"2ch audio, no pre-emphasis, digital copy permitted";
		case 0x03: return @"2ch audio, with pre-emphasis, digital copy permitted";
		case 0x04: return @"data track, digital copy prohibited";
		case 0x06: return @"data track, digital copy permitted";
		case 0x08: return @"4ch audio, no pre-emphasis, digital copy prohibited";
		case 0x09: return @"4ch audio, with pre-emphasis, digital copy prohibited";
		case 0x0A: return @"4ch audio, no pre-emphasis, digital copy permitted";
		case 0x0B: return @"4ch audio, with pre-emphasis, digital copy permitted";
		default:   return @"Unknown";
	}
}

- (NSString *) getChannels
{
	switch([_type intValue]) {
		case 0x00: return @"2";
		case 0x01: return @"2";
		case 0x02: return @"2";
		case 0x03: return @"2";
		case 0x04: return @"-";
		case 0x06: return @"-";
		case 0x08: return @"4";
		case 0x09: return @"4";
		case 0x0A: return @"4";
		case 0x0B: return @"4";
		default:   return @"Unknown";
	}
}

- (NSString *) getPreEmphasis
{
	switch([_type intValue]) {
		case 0x00: return @"No";
		case 0x01: return @"Yes";
		case 0x02: return @"No";
		case 0x03: return @"Yes";
		case 0x04: return @"-";
		case 0x06: return @"-";
		case 0x08: return @"No";
		case 0x09: return @"Yes";
		case 0x0A: return @"No";
		case 0x0B: return @"Yes";
		default:   return @"Unknown";
	}	
}

- (NSString *) getCopyPermitted
{
	switch([_type intValue]) {
		case 0x00: return @"No";
		case 0x01: return @"No";
		case 0x02: return @"Yes";
		case 0x03: return @"Yes";
		case 0x04: return @"No";
		case 0x06: return @"Yes";
		case 0x08: return @"No";
		case 0x09: return @"No";
		case 0x0A: return @"Yes";
		case 0x0B: return @"Yes";
		default:   return @"No";
	}	
}

- (NSNumber *) getFirstSector
{
	CDMSF msf;
	
	msf.minute	= [_minute unsignedIntValue];
	msf.second	= [_second unsignedIntValue];
	msf.frame	= [_frame unsignedIntValue];
	
	return [NSNumber numberWithUnsignedInt:CDConvertMSFToLBA(msf)];
}

- (NSNumber *) getSize
{
	unsigned int size;
	
	size = ([_lastSector unsignedIntValue] - [[self getFirstSector] unsignedIntValue]) * kCDSectorSizeCDDA;
	return [NSNumber numberWithUnsignedInt:size];
}

- (NSString *) getLength
{
	CDMSF msf;
	
	// subtract 2 second lead-in
	msf = CDConvertLBAToMSF([_lastSector unsignedIntValue] - [[self getFirstSector] unsignedIntValue] - 150);
	return [NSString stringWithFormat:@"%i:%02i", msf.minute, msf.second ];
}

- (NSNumber *) getDuration
{
	CDMSF msf;
	
	// subtract 2 second lead-in
	msf = CDConvertLBAToMSF([_lastSector unsignedIntValue] - [[self getFirstSector] unsignedIntValue] - 150);
	return [NSNumber numberWithUnsignedInt:60 * msf.minute + msf.second];
}

- (NSColor *) getColor
{
	NSColor *result;
	NSData *data;
	
	result = nil;
	
	if(nil != _artist || nil != _year || nil != _genre) {
		data = [[NSUserDefaults standardUserDefaults] dataForKey:@"org.sbooth.Max.customTrackColor"];
		if(nil != data)
			result = (NSColor *)[NSUnarchiver unarchiveObjectWithData:data];
	}

	return result;
}

- (void) dealloc
{
	[_number release];
	[_minute release];
	[_second release];
	[_frame release];
	[_type release];
	[_title release];
	[super dealloc];
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	NSMutableDictionary *result = [[[NSMutableDictionary alloc] init] autorelease];
	
	[result setValue:_number forKey:@"number"];

	[result setValue:_selected forKey:@"selected"];
	[result setValue:_color forKey:@"color"];
	[result setValue:_title forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];;
	[result setValue:_genre forKey:@"genre"];

	return result;
}

- (void) setPropertiesFromDictionary:(NSDictionary *)properties
{
	if(NO == [[properties valueForKey:@"number"] isEqualToNumber:[self valueForKey:@"number"]]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track number mismatch" userInfo:nil];
	}
	
	[self setValue:[properties valueForKey:@"selected"] forKey:@"selected"];
	[self setValue:[properties valueForKey:@"color"] forKey:@"color"];
	[self setValue:[properties valueForKey:@"title"] forKey:@"title"];
	[self setValue:[properties valueForKey:@"artist"] forKey:@"artist"];
	[self setValue:[properties valueForKey:@"year"] forKey:@"year"];
	[self setValue:[properties valueForKey:@"genre"] forKey:@"genre"];
}

@end
