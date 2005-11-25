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
		
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"minute"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"second"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"frame"];
		
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"size"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"length"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"duration"];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ %@ %@", _number, _title, [self getLength]];
}

#pragma mark Accessors

- (unsigned) getMinute
{
	unsigned long	sector		= [_firstSector unsignedLongValue];
	unsigned long	offset		= [_lastSector unsignedLongValue] - sector + 1;
	
	return (unsigned) (offset / (60 * 75));
}

- (unsigned) getSecond
{
	unsigned long	sector		= [_firstSector unsignedLongValue];
	unsigned long	offset		= [_lastSector unsignedLongValue] - sector + 1;
	
	return (unsigned) ((offset / 75) % 60);
}

- (unsigned) getFrame
{
	unsigned long	sector		= [_firstSector unsignedLongValue];
	unsigned long	offset		= [_lastSector unsignedLongValue] - sector + 1;
	
	return (unsigned) (offset % 75);
}

- (NSString *) getPreEmphasis
{
	return [_preEmphasis boolValue] ? @"Yes" : @"No";
}

- (NSString *) getCopyPermitted
{
	return [_copyPermitted boolValue] ? @"Yes" : @"No";
}

- (NSNumber *) getSize
{
	unsigned long size = ([_lastSector unsignedLongValue] - [_firstSector unsignedLongValue]) * kCDSectorSizeCDDA;
	return [NSNumber numberWithUnsignedLong:size];
}

- (NSString *) getLength
{
	return [NSString stringWithFormat:@"%i:%02i", [self getMinute], [self getSecond]];
}

- (NSColor *) getColor
{
	NSColor *result;
	NSData *data;
	
	result = nil;
	
	if(nil != _artist || nil != _year || nil != _genre) {
		data = [[NSUserDefaults standardUserDefaults] dataForKey:@"customTrackColor"];
		if(nil != data)
			result = (NSColor *)[NSUnarchiver unarchiveObjectWithData:data];
	}
	
	return result;
}

- (void) clearFreeDBData
{
	[self setValue:nil forKey:@"title"];
	[self setValue:nil forKey:@"artist"];
	[self setValue:nil forKey:@"year"];
	[self setValue:nil forKey:@"genre"];
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	[result setValue:_selected forKey:@"selected"];
	[result setValue:_color forKey:@"color"];

	[result setValue:_title forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];;
	[result setValue:_genre forKey:@"genre"];

	[result setValue:_number forKey:@"number"];
	[result setValue:_firstSector forKey:@"firstSector"];
	[result setValue:_lastSector forKey:@"lastSector"];
	[result setValue:_channels forKey:@"channels"];
	[result setValue:_preEmphasis forKey:@"preEmphasis"];
	[result setValue:_copyPermitted forKey:@"copyPermitted"];
	
	return [[result retain] autorelease];
}

- (void) setPropertiesFromDictionary:(NSDictionary *)properties
{	
	[self setValue:[properties valueForKey:@"selected"] forKey:@"selected"];
	[self setValue:[properties valueForKey:@"color"] forKey:@"color"];
	
	[self setValue:[properties valueForKey:@"title"] forKey:@"title"];
	[self setValue:[properties valueForKey:@"artist"] forKey:@"artist"];
	[self setValue:[properties valueForKey:@"year"] forKey:@"year"];
	[self setValue:[properties valueForKey:@"genre"] forKey:@"genre"];

	[self setValue:[properties valueForKey:@"number"] forKey:@"number"];
	[self setValue:[properties valueForKey:@"firstSector"] forKey:@"firstSector"];
	[self setValue:[properties valueForKey:@"lastSector"] forKey:@"lastSector"];
	[self setValue:[properties valueForKey:@"channels"] forKey:@"channels"];
	[self setValue:[properties valueForKey:@"preEmphasis"] forKey:@"preEmphasis"];
	[self setValue:[properties valueForKey:@"copyPermitted"] forKey:@"copyPermitted"];
}

@end
