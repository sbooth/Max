/*
 *  $Id: CompactDisc.h 122 2005-11-18 21:57:28Z me $
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

#import "CDDrive.h"

#import "ParanoiaException.h"

@implementation CDDrive

- (id) init
{
	@throw [NSException exceptionWithName:@"InternalInconsistencyException" reason:@"CDDrive init called" userInfo:nil];
	return nil;
}

- (id) initWithBSDName:(NSString *) bsdName
{
	if((self = [super init])) {
		_bsdName = [bsdName retain];
		
		_drive = cdda_identify([_bsdName UTF8String], 0, NULL);
		if(NULL == _drive) {
			@throw [ParanoiaException exceptionWithReason:@"cdda_identify failed" userInfo:nil];
		}
		
		if(0 != cdda_open(_drive)) {
			@throw [ParanoiaException exceptionWithReason:@"cdda_open failed" userInfo:nil];
		}
	}
	return self;
}

- (void) dealloc
{
	[_bsdName release];
	
	if(0 != cdda_close(_drive)) {
		@throw [ParanoiaException exceptionWithReason:@"cdda_close failed" userInfo:nil];
	}
	
	[super dealloc];
}

/*- (cdrom_drive *) drive
{
	return _drive;
}*/

- (unsigned) trackCount
{
	return cdda_tracks(_drive);
}

- (unsigned long) firstSector
{
	return cdda_disc_firstsector(_drive);
}

- (unsigned long) lastSector
{
	return cdda_disc_lastsector(_drive);
}

- (unsigned) trackContainingSector:(unsigned long) sector
{
	return cdda_sector_gettrack(_drive, sector);
}

- (unsigned long) firstSectorForTrack:(ssize_t) track
{
	return cdda_track_firstsector(_drive, track);
}

- (unsigned long) lastSectorForTrack:(ssize_t) track
{
	return cdda_track_lastsector(_drive, track);
}

- (unsigned) channelsForTrack:(ssize_t) track;
{
	return cdda_track_channels(_drive, track);
}

- (BOOL) trackContainsAudio:(ssize_t) track
{
	return cdda_track_audiop(_drive, track) ? YES : NO;
}

- (BOOL) trackHasPreEmphasis:(ssize_t) track
{
	return cdda_track_preemp(_drive, track) ? YES : NO;
}

- (BOOL) trackAllowsDigitalCopy:(ssize_t) track
{
	return cdda_track_copyp(_drive, track) ? YES : NO;
}

@end
