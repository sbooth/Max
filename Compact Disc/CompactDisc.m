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

#import "CompactDisc.h"

#import "MallocException.h"
#import "Drive.h"
#import "IOException.h"
#import "FreeDBException.h"

#include <paths.h>			// _PATH_DEV

@implementation CompactDisc

- (id) initWithDeviceName:(NSString *)deviceName;
{
	if((self = [super init])) {
		unsigned				i;
		unsigned long			discLength		= 150;
		Drive					*drive			= nil;
		TrackDescriptor			*track			= nil;
		NSMutableDictionary		*trackInfo		= nil;
		NSString				*ISRC			= nil;

		_deviceName		= [deviceName retain];

		// To avoid keeping an open file descriptor, read the disc's properties from the drive
		// and store them in our ivars
		drive = [[[Drive alloc] initWithDeviceName:[self deviceName]] autorelease];
		
		// Disc information
		_firstSector	= [[drive trackNumber:[drive firstTrack]] firstSector];
		_lastSector		= [drive leadOut];

		_MCN = [[drive readMCN] retain];
		
		// Iterate through the tracks and get their information
		_tracks		= [[NSMutableArray arrayWithCapacity:[drive countOfTracks] + 1] retain];
		
		for(i = [drive firstTrack]; i <= [drive lastTrack]; ++i) {

			track = [drive trackNumber:i];
			
			trackInfo = [NSMutableDictionary dictionaryWithCapacity:6];
		
			[trackInfo setObject:[NSNumber numberWithUnsignedInt:i] forKey:@"number"];

			[trackInfo setObject:[NSNumber numberWithUnsignedInt:[drive firstSectorForTrack:i]] forKey:@"firstSector"];
			[trackInfo setObject:[NSNumber numberWithUnsignedInt:[drive lastSectorForTrack:i]] forKey:@"lastSector"];

			[trackInfo setObject:[NSNumber numberWithUnsignedInt:[track channels]] forKey:@"channels"];

			[trackInfo setObject:[NSNumber numberWithBool:(NO == [track dataTrack])] forKey:@"containsAudio"];
			[trackInfo setObject:[NSNumber numberWithBool:[track preEmphasis]] forKey:@"preEmphasis"];
			[trackInfo setObject:[NSNumber numberWithBool:[track copyPermitted]] forKey:@"allowsDigitalCopy"];

			ISRC = [drive readISRC:i];
			if(nil != ISRC) {
				[trackInfo setObject:ISRC forKey:@"ISRC"];
			}
			
			[_tracks addObject:trackInfo];
		}
		
		// Setup libcddb data structures
		_freeDBDisc	= cddb_disc_new();
		if(NULL == _freeDBDisc) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(i = 0; i < [self countOfTracks]; ++i) {
			cddb_track_t *cddb_track;
			
			cddb_track = cddb_track_new();
			if(NULL == cddb_track) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			cddb_track_set_frame_offset(cddb_track, [self firstSectorForTrack:i] + 150);
			cddb_disc_add_track(_freeDBDisc, cddb_track);
			discLength += [self lastSectorForTrack:i] - [self firstSectorForTrack:i] + 1;
		}
		_length = (unsigned) (60 * (discLength / (60 * 75))) + (unsigned)((discLength / 75) % 60);
		cddb_disc_set_length(_freeDBDisc, _length);
		
		if(0 == cddb_disc_calc_discid(_freeDBDisc)) {
			@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to calculate the disc's FreeDB ID.", @"Exceptions", @"") userInfo:nil];
		}
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_deviceName release];
	[_tracks release];
	[_MCN release];
		
	if(NULL != _freeDBDisc) {
		cddb_disc_destroy(_freeDBDisc);
	}
	
	[super dealloc];
}

- (NSString *)		deviceName								{ return _deviceName; }

- (NSString *)		MCN										{ return _MCN; }

- (unsigned)		firstSector								{ return _firstSector; }
- (unsigned)		lastSector								{ return _lastSector; }

- (unsigned)		firstSectorForTrack:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"firstSector"] unsignedIntValue]; }
- (unsigned)		lastSectorForTrack:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"lastSector"] unsignedIntValue]; }

- (unsigned)		channelsForTrack:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"channels"] unsignedIntValue]; }

- (BOOL)			trackContainsAudio:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"containsAudio"] boolValue]; }
- (BOOL)			trackHasPreEmphasis:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"hasPreEmphasis"] boolValue]; }
- (BOOL)			trackAllowsDigitalCopy:(unsigned)track	{ return [[[self objectInTracksAtIndex:track] objectForKey:@"allowsDigitalCopy"] boolValue]; }

- (NSString *)		ISRCForTrack:(unsigned)track			{ return [[self objectInTracksAtIndex:track] objectForKey:@"ISRC"]; }

- (int)				discID									{ return cddb_disc_get_discid(_freeDBDisc); }
- (unsigned)		length									{ return _length; }

// KVC
- (unsigned)		countOfTracks							{ return [_tracks count]; }
- (NSDictionary *)	objectInTracksAtIndex:(unsigned)idx		{ return [_tracks objectAtIndex:idx]; }

- (cddb_disc_t *)	freeDBDisc								{ return _freeDBDisc; }

@end
