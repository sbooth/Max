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
#import "IOException.h"
#import "ParanoiaException.h"
#import "FreeDBException.h"

#include <paths.h>			// _PATH_DEV

@implementation CompactDisc

- (id) initWithBSDName:(NSString *)bsdName;
{
	if((self = [super init])) {
		unsigned			i;
		unsigned long		discLength	= 150;
		NSString			*bsdPath	= [NSString stringWithFormat:@"%@r%@", [NSString stringWithCString:_PATH_DEV encoding:NSASCIIStringEncoding], bsdName];
		char				*MCN		= NULL;
		cdrom_drive			*drive		= NULL;
		unsigned			trackCount	= 0;


		// cdparanoia setup
		drive = cdda_identify([bsdPath fileSystemRepresentation], 0, NULL);
		if(NULL == drive) {
			@throw [ParanoiaException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"cdda_identify"] userInfo:nil];
		}
		
		if(0 != cdda_open(drive)) {
			@throw [ParanoiaException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"cdda_open"] userInfo:nil];
		}

		_bsdName		= [bsdName retain];
		_deviceName		= [[NSString stringWithCString:drive->device_name encoding:NSASCIIStringEncoding] retain];
		
		// Disc information
		_firstSector	= cdda_disc_firstsector(drive);
		_lastSector		= cdda_disc_lastsector(drive);

		MCN = cdda_disc_mcn(drive);		
		if(NULL != MCN) {
			_MCN = [[NSString stringWithCString:MCN encoding:NSASCIIStringEncoding] retain];
			free(MCN);
		}
		
		// Iterate through the tracks and get their information
		trackCount	= cdda_tracks(drive);
		_tracks		= [[NSMutableArray arrayWithCapacity:trackCount + 1] retain];
		
		// paranoia's tracks are 1-based
		for(i = 1; i <= trackCount; ++i) {
			NSMutableDictionary		*trackInfo;
			char					*ISRC;

			trackInfo = [NSMutableDictionary dictionaryWithCapacity:6];
		
			[trackInfo setObject:[NSNumber numberWithUnsignedInt:i] forKey:@"number"];

			[trackInfo setObject:[NSNumber numberWithUnsignedLong:cdda_track_firstsector(drive, i)] forKey:@"firstSector"];
			[trackInfo setObject:[NSNumber numberWithUnsignedLong:cdda_track_lastsector(drive, i)] forKey:@"lastSector"];

			[trackInfo setObject:[NSNumber numberWithUnsignedInt:cdda_track_channels(drive, i)] forKey:@"channels"];

			[trackInfo setObject:[NSNumber numberWithBool:cdda_track_audiop(drive, i)] forKey:@"containsAudio"];
			[trackInfo setObject:[NSNumber numberWithBool:cdda_track_preemp(drive, i)] forKey:@"preEmphasis"];
			[trackInfo setObject:[NSNumber numberWithBool:cdda_track_copyp(drive, i)] forKey:@"allowsDigitalCopy"];

			ISRC = cdda_track_isrc(drive, i);
			if(NULL != ISRC) {
				[trackInfo setObject:[NSString stringWithCString:ISRC encoding:NSASCIIStringEncoding] forKey:@"ISRC"];
				free(ISRC);
			}
			
			[_tracks addObject:trackInfo];
		}
		
		cdda_close(drive);

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
	[_bsdName release];
	[_deviceName release];
	[_tracks release];
	[_MCN release];
		
	if(NULL != _freeDBDisc) {
		cddb_disc_destroy(_freeDBDisc);
	}
	
	[super dealloc];
}

- (NSString *)		bsdName									{ return _bsdName; }
- (NSString *)		deviceName								{ return _deviceName; }

- (NSString *)		MCN										{ return _MCN; }

- (unsigned long)	firstSector								{ return _firstSector; }
- (unsigned long)	lastSector								{ return _lastSector; }

- (unsigned long)	firstSectorForTrack:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"firstSector"] unsignedLongValue]; }
- (unsigned long)	lastSectorForTrack:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"lastSector"] unsignedLongValue]; }

- (unsigned)		channelsForTrack:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"channels"] unsignedIntValue]; }

- (BOOL)			trackContainsAudio:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"containsAudio"] boolValue]; }
- (BOOL)			trackHasPreEmphasis:(unsigned)track		{ return [[[self objectInTracksAtIndex:track] objectForKey:@"hasPreEmphasis"] boolValue]; }
- (BOOL)			trackAllowsDigitalCopy:(unsigned)track	{ return [[[self objectInTracksAtIndex:track] objectForKey:@"allowsDigitalCopy"] boolValue]; }

- (NSString *)		ISRCForTrack:(unsigned)track			{ return [[self objectInTracksAtIndex:track] objectForKey:@"ISRC"]; }

- (int)				discID									{ return cddb_disc_get_discid(_freeDBDisc); }
- (unsigned)		length									{ return _length; }

// KVC
- (unsigned int)	countOfTracks							{ return [_tracks count]; }
- (NSDictionary *)	objectInTracksAtIndex:(unsigned int)idx	{ return [_tracks objectAtIndex:idx]; }

- (cddb_disc_t *)	freeDBDisc								{ return _freeDBDisc; }

@end
