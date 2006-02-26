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
		NSString			*bsdPath	= [NSString stringWithFormat:@"%@r%@", [NSString stringWithUTF8String:_PATH_DEV], bsdName];
		char				*MCN		= NULL;
		cdrom_drive			*drive		= NULL;
		unsigned			trackCount	= 0;


		// cdparanoia setup
		drive = cdda_identify([bsdPath fileSystemRepresentation], 0, NULL);
		if(NULL == drive) {
			@throw [ParanoiaException exceptionWithReason:NSLocalizedStringFromTable(@"cdda_identify failed", @"Exceptions", @"") userInfo:nil];
		}
		
		if(0 != cdda_open(drive)) {
			@throw [ParanoiaException exceptionWithReason:NSLocalizedStringFromTable(@"cdda_open failed", @"Exceptions", @"") userInfo:nil];
		}

		_bsdName		= [bsdName retain];
		_deviceName		= [[NSString stringWithUTF8String:drive->device_name] retain];
		
		// Disc information
		_firstSector	= [[NSNumber numberWithUnsignedLong:cdda_disc_firstsector(drive)] retain];
		_lastSector		= [[NSNumber numberWithUnsignedLong:cdda_disc_lastsector(drive)] retain];

		MCN = cdda_disc_mcn(drive);		
		if(NULL != MCN) {
			_MCN = [[NSString stringWithCString:MCN encoding:NSASCIIStringEncoding] retain];
			free(MCN);
		}
		
		// Iterate through the tracks and get their information
		trackCount	= cdda_tracks(drive);
		_tracks		= [[NSMutableArray arrayWithCapacity:trackCount] retain];
		
		// paranoia's tracks are 1-based
		for(i = 1; i <= trackCount; ++i) {
			NSMutableDictionary		*trackInfo;
			char					*ISRC;

			trackInfo = [NSMutableDictionary dictionaryWithCapacity:6];
		
			[trackInfo setValue:[NSNumber numberWithUnsignedInt:i] forKey:@"number"];

			[trackInfo setValue:[NSNumber numberWithUnsignedLong:cdda_track_firstsector(drive, i)] forKey:@"firstSector"];
			[trackInfo setValue:[NSNumber numberWithUnsignedLong:cdda_track_lastsector(drive, i)] forKey:@"lastSector"];

			[trackInfo setValue:[NSNumber numberWithUnsignedInt:cdda_track_channels(drive, i)] forKey:@"channels"];

			[trackInfo setValue:[NSNumber numberWithBool:cdda_track_audiop(drive, i)] forKey:@"containsAudio"];
			[trackInfo setValue:[NSNumber numberWithBool:cdda_track_preemp(drive, i)] forKey:@"preEmphasis"];
			[trackInfo setValue:[NSNumber numberWithBool:cdda_track_copyp(drive, i)] forKey:@"allowsDigitalCopy"];

			ISRC = cdda_track_isrc(drive, i);
			if(NULL != ISRC) {
				[trackInfo setValue:[NSString stringWithCString:ISRC encoding:NSASCIIStringEncoding] forKey:@"ISRC"];
				free(ISRC);
			}
			
			[_tracks addObject:trackInfo];
		}
		
		cdda_close(drive);

		// Setup libcddb data structures
		_freeDBDisc	= cddb_disc_new();
		if(NULL == _freeDBDisc) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(i = 0; i < [self trackCount]; ++i) {
			cddb_track_t *cddb_track;
			
			cddb_track = cddb_track_new();
			if(NULL == cddb_track) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			cddb_track_set_frame_offset(cddb_track, [self firstSectorForTrack:i] + 150);
			cddb_disc_add_track(_freeDBDisc, cddb_track);
			discLength += [self lastSectorForTrack:i] - [self firstSectorForTrack:i] + 1;
		}
		_length = (unsigned) (60 * (discLength / (60 * 75))) + (unsigned)((discLength / 75) % 60);
		cddb_disc_set_length(_freeDBDisc, _length);
		
		if(0 == cddb_disc_calc_discid(_freeDBDisc)) {
			@throw [FreeDBException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to calculate disc id", @"Exceptions", @"") userInfo:nil];
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
	[_firstSector release];
	[_lastSector release];
		
	if(NULL != _freeDBDisc) {
		cddb_disc_destroy(_freeDBDisc);
	}
	
	[super dealloc];
}

- (NSString *)		bsdName									{ return _bsdName; }
- (NSString *)		deviceName								{ return _deviceName; }

- (unsigned)		trackCount								{ return [_tracks count]; }

- (NSString *)		MCN										{ return _MCN; }

- (unsigned long)	firstSector								{ return [_firstSector unsignedLongValue]; }
- (unsigned long)	lastSector								{ return [_lastSector unsignedLongValue]; }

- (unsigned long)	firstSectorForTrack:(unsigned)track		{ return [[[_tracks objectAtIndex:track] valueForKey:@"firstSector"] unsignedLongValue]; }
- (unsigned long)	lastSectorForTrack:(unsigned)track		{ return [[[_tracks objectAtIndex:track] valueForKey:@"lastSector"] unsignedLongValue]; }

- (unsigned)		channelsForTrack:(unsigned)track		{ return [[[_tracks objectAtIndex:track] valueForKey:@"channels"] unsignedIntValue]; }

- (BOOL)			trackContainsAudio:(unsigned)track		{ return [[[_tracks objectAtIndex:track] valueForKey:@"containsAudio"] boolValue]; }
- (BOOL)			trackHasPreEmphasis:(unsigned)track		{ return [[[_tracks objectAtIndex:track] valueForKey:@"hasPreEmphasis"] boolValue]; }
- (BOOL)			trackAllowsDigitalCopy:(unsigned)track	{ return [[[_tracks objectAtIndex:track] valueForKey:@"allowsDigitalCopy"] boolValue]; }

- (NSString *)		ISRC:(unsigned) track					{ return [[_tracks objectAtIndex:track] valueForKey:@"ISRC"]; }

- (int)				discID									{ return cddb_disc_get_discid(_freeDBDisc); }
- (unsigned)		length									{ return _length; }

// KVC
- (unsigned int)	countOfTracks								{ return [_tracks count]; }
- (NSDictionary *)	objectInTracksAtIndex:(unsigned int)index	{ return [_tracks objectAtIndex:index]; }

- (cddb_disc_t *)	getFreeDBDisc								{ return _freeDBDisc; }

@end
