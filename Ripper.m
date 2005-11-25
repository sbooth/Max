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

#import "Ripper.h"
#import "MallocException.h"
#import "StopException.h"
#import "IOException.h"

#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close

@implementation Ripper

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Ripper::init called" userInfo:nil];
}

- (id) initWithDisc:(CompactDiscDocument *) disc forTrack:(Track *) track
{
	if((self = [super init])) {
		
		_disc	= [disc retain];
		_track	= [track retain];
		
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"started"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"completed"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"stopped"];
		
		// Setup cdparanoia
		_drive		= [[_disc getDisc] getDrive];
		_paranoia	= paranoia_init(_drive);
		
		/* full paranoia, but allow skipping */
		int paranoia_mode = PARANOIA_MODE_FULL ^ PARANOIA_MODE_NEVERSKIP; 
		paranoia_modeset(_paranoia, paranoia_mode);
		
		// Determine the size of the track we are ripping
		_firstSector	= [[_track valueForKey:@"firstSector"] unsignedLongValue];
		_lastSector		= [[_track valueForKey:@"lastSector"] unsignedLongValue];
		
		// Go to the track's first sector in preparation for reading
		long where = paranoia_seek(_paranoia, _firstSector, SEEK_SET);   	    
		if(-1 == where) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			paranoia_free(_paranoia);
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	paranoia_free(_paranoia);
	
	[_disc release];
	[_track release];
	
	[super dealloc];
}

- (void) requestStop
{
	@synchronized(self) {
		if([_started boolValue]) {
			_shouldStop = [NSNumber numberWithBool:YES];			
		}
		else {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		}
	}
}

- (void) ripToFile:(int) file
{
	unsigned long		cursor				= _firstSector;
	int16_t				*buf				= NULL;
	NSDate				*startTime			= [NSDate date];
	unsigned long		totalSectors		= _lastSector - _firstSector + 1;
	unsigned long		sectorsToRead		= totalSectors;
	
	// Tell our owner we are starting
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	while(cursor <= _lastSector) {

		// Check if we should stop, and if so throw an exception
		if([_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk
		buf = paranoia_read_limited(_paranoia, NULL, 20/*max_retries*/);
		if(NULL == buf) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];			
		}
				
		// Update status
		sectorsToRead--;
		if(0 == sectorsToRead % 10) {
			[self setValue:[NSNumber numberWithDouble:((double)(totalSectors - sectorsToRead)/(double) totalSectors) * 100.0] forKey:@"percentComplete"];
			NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
			unsigned int timeRemaining = interval / ((double)(totalSectors - sectorsToRead)/(double) totalSectors) - interval;
			[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
		}
		
		// Write data to file
		if(-1 == write(file, (unsigned char *)buf, CD_FRAMESIZE_RAW)) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Advance cursor
		++cursor;
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
}

@end
