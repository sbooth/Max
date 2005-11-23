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

#import "CompactDisc.h"
#import "Track.h"
#import "MallocException.h"
#import "IOException.h"
#import "FreeDBException.h"

#include "cddb/cddb_track.h"

#include <sys/param.h>		// MAXPATHLEN
#include <paths.h>			//_PATH_DEV


@implementation CompactDisc

- (id) init
{
	@throw [NSException exceptionWithName:@"InternalInconsistencyException" reason:@"CompactDisc init called" userInfo:nil];
	return nil;
}

- (id) initWithBSDName:(NSString *) bsdName
{
	if((self = [super init])) {
		unsigned			i;
		unsigned long		discLength	= 150;
		
		_tracks		= [[NSMutableArray alloc] initWithCapacity:20];
		_drive		= [[CDDrive alloc] initWithBSDName:bsdName];

		
		for(i = 1; i <= [_drive trackCount]; ++i) {
			Track			*track		= [[Track alloc] init];
			
			[track setValue:[NSNumber numberWithUnsignedInt:i] forKey:@"number"];
			[track setValue:[NSNumber numberWithUnsignedLong:[_drive firstSectorForTrack:i]] forKey:@"firstSector"];
			[track setValue:[NSNumber numberWithUnsignedLong:[_drive lastSectorForTrack:i]] forKey:@"lastSector"];

			[track setValue:[NSNumber numberWithUnsignedInt:[_drive channelsForTrack:i]] forKey:@"channels"];
			[track setValue:[NSNumber numberWithUnsignedInt:[_drive trackHasPreEmphasis:i]] forKey:@"preEmphasis"];
			[track setValue:[NSNumber numberWithUnsignedInt:[_drive trackAllowsDigitalCopy:i]] forKey:@"copyPermitted"];

			[_tracks addObject: track];
			
			discLength += [_drive lastSectorForTrack:i] - [_drive firstSectorForTrack:i] + 1;
		}
		
		// Setup libcddb data structures
		_cddb_disc	= cddb_disc_new();
		if(NULL == _cddb_disc) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		
		_length = (unsigned) (60 * (discLength / (60 * 75))) + (unsigned)((discLength / 75) % 60);
		cddb_disc_set_length(_cddb_disc, _length);
		for(i = 1; i <= [_drive trackCount]; ++i) {
			cddb_track_t	*cddb_track	= cddb_track_new();
			if(NULL == cddb_track) {
				@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
			}
			cddb_track_set_frame_offset(cddb_track, [_drive firstSectorForTrack:i] + 150);
			cddb_disc_add_track(_cddb_disc, cddb_track);
		}
		
		if(0 == cddb_disc_calc_discid(_cddb_disc)) {
			@throw [CDDBException exceptionWithReason:@"Unable to calculate disc id" userInfo:nil];
		}
	}
	
	return self;
}

- (void) dealloc
{
	[_tracks release];
	[_drive release];
	
	cddb_disc_destroy(_cddb_disc);
	
	[super dealloc];
}

- (unsigned long)	cddb_id			{ return cddb_disc_get_discid(_cddb_disc); }
- (cddb_disc_t *)	cddb_disc		{ return _cddb_disc; }
- (NSString *)		length			{ return [NSString stringWithFormat:@"%u:%.02u", _length / 60, _length % 60]; }


- (NSArray *) selectedTracks
{
	NSMutableArray	*result			= [[[NSMutableArray alloc] initWithCapacity:[_drive trackCount]] autorelease];
	NSEnumerator	*enumerator		= [_tracks objectEnumerator];
	Track			*track;
	
	while((track = [enumerator nextObject])) {
		if([[track valueForKey:@"selected"] boolValue]) {
			[result addObject: track];
		}
	}
	
	return result;
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	unsigned				i;
	NSMutableDictionary		*result		= [[[NSMutableDictionary alloc] init] autorelease];
	NSMutableArray			*tracks		= [[[NSMutableArray alloc] initWithCapacity:[_tracks count]] autorelease];
		
	[result setValue:[self valueForKey:@"title"] forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];
	[result setValue:_genre forKey:@"genre"];
	[result setValue:_comment forKey:@"comment"];
	[result setValue:_discNumber forKey:@"discNumber"];
	[result setValue:_discsInSet forKey:@"discsInSet"];
	[result setValue:_multiArtist forKey:@"multiArtist"];
	
	for(i = 0; i < [_tracks count]; ++i) {
		[tracks addObject:[[_tracks objectAtIndex:i] getDictionary]];
	}
	
	[result setValue:tracks forKey:@"tracks"];
	
	return result;
}

- (void) setPropertiesFromDictionary:(NSDictionary *) properties
{
	unsigned				i;
	NSArray					*tracks			= [properties valueForKey:@"tracks"];
	
	if([tracks count] != [_tracks count]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track count mismatch" userInfo:nil];
	}

	for(i = 0; i < [tracks count]; ++i) {
		[[_tracks objectAtIndex:i] setPropertiesFromDictionary:[tracks objectAtIndex:i]];
	}
	
	[self setValue:[properties valueForKey:@"title"] forKey:@"title"];
	[self setValue:[properties valueForKey:@"artist"] forKey:@"artist"];
	[self setValue:[properties valueForKey:@"year"] forKey:@"year"];
	[self setValue:[properties valueForKey:@"genre"] forKey:@"genre"];
	[self setValue:[properties valueForKey:@"comment"] forKey:@"comment"];
	[self setValue:[properties valueForKey:@"discNumber"] forKey:@"discNumber"];
	[self setValue:[properties valueForKey:@"discsInSet"] forKey:@"discsInSet"];
	[self setValue:[properties valueForKey:@"multiArtist"] forKey:@"multiArtist"];
}

@end
