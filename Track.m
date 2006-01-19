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
			@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to load '%@'", @"Exceptions", @""), @"TrackDefaults.plist"] userInfo:nil];
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

- (id) init
{
	if((self = [super init])) {
		_activeEncoders = 0;
		return self;
	}
	return nil;
}

- (NSString *) description
{
	NSString			*discArtist			= [_disc valueForKey:@"artist"];
	NSString			*trackArtist		= _artist;
	NSString			*artist;
	NSString			*trackTitle			= _title;
	
	artist = trackArtist;
	if(nil == artist) {
		artist = discArtist;
		if(nil == artist) {
			artist = @"Unknown Artist";
		}
	}
	if(nil == trackTitle) {
		trackTitle = @"Unknown Track";
	}
	
	
	if([[_disc valueForKey:@"multiArtist"] boolValue]) {
		return [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
	}
	else {
		return [NSString stringWithFormat:@"%@", trackTitle];		
	}
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
	return [_preEmphasis boolValue] ? NSLocalizedStringFromTable(@"Yes", @"General", @"") : NSLocalizedStringFromTable(@"No", @"General", @"");
}

- (NSString *) getCopyPermitted
{
	return [_copyPermitted boolValue] ? NSLocalizedStringFromTable(@"Yes", @"General", @"") : NSLocalizedStringFromTable(@"No", @"General", @"");
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

- (CompactDiscDocument *) getCompactDiscDocument
{
	return _disc;
}

- (void) encodeStarted
{
	[self willChangeValueForKey:@"encodeInProgress"];
	++_activeEncoders;
	[self didChangeValueForKey:@"encodeInProgress"];
}

- (void) encodeCompleted
{
	[self willChangeValueForKey:@"encodeInProgress"];
	--_activeEncoders;
	[self didChangeValueForKey:@"encodeInProgress"];
}

- (NSNumber *) encodeInProgress
{
	return [NSNumber numberWithBool:(0 != _activeEncoders)];
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

- (id) copyWithZone:(NSZone *)zone
{
	Track *copy = [[Track allocWithZone:zone] init];
	
	[copy setValue:_disc forKey:@"disc"];
	
	[copy setValue:_selected forKey:@"selected"];
	[copy setValue:_color forKey:@"color"];
	
	[copy setValue:_title forKey:@"title"];
	[copy setValue:_artist forKey:@"artist"];
	[copy setValue:_year forKey:@"year"];;
	[copy setValue:_genre forKey:@"genre"];
	
	[copy setValue:_number forKey:@"number"];
	[copy setValue:_firstSector forKey:@"firstSector"];
	[copy setValue:_lastSector forKey:@"lastSector"];
	[copy setValue:_channels forKey:@"channels"];
	[copy setValue:_preEmphasis forKey:@"preEmphasis"];
	[copy setValue:_copyPermitted forKey:@"copyPermitted"];

	return copy;
}

- (AudioMetadata *) metadata
{
	AudioMetadata *result = [[AudioMetadata alloc] init];

	[result setValue:_number forKey:@"trackNumber"];
	[result setValue:_title forKey:@"trackTitle"];
	[result setValue:_artist forKey:@"trackArtist"];
	[result setValue:_year forKey:@"trackYear"];
	[result setValue:_genre forKey:@"trackGenre"];
	//[result setValue:nil_comment forKey:@"trackComment"];
		
	[result setValue:[NSNumber numberWithInt:[[_disc valueForKey:@"tracks"] count]] forKey:@"albumTrackCount"];
	[result setValue:[_disc valueForKey:@"title"] forKey:@"albumTitle"];
	[result setValue:[_disc valueForKey:@"artist"] forKey:@"albumArtist"];
	[result setValue:[_disc valueForKey:@"year"] forKey:@"albumYear"];
	[result setValue:[_disc valueForKey:@"genre"] forKey:@"albumGenre"];
	[result setValue:[_disc valueForKey:@"comment"] forKey:@"albumComment"];
		
	[result setValue:[_disc valueForKey:@"discNumber"] forKey:@"discNumber"];
	[result setValue:[_disc valueForKey:@"discsInSet"] forKey:@"discsInSet"];
	[result setValue:[_disc valueForKey:@"multiArtist"] forKey:@"multipleArtists"];
	
	
	return [result autorelease];
}


@end
