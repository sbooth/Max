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
#import "Track.h"
#import "SectorRange.h"
#import "LogController.h"
#import "CompactDiscDocument.h"
#import "CompactDisc.h"
#import "MallocException.h"
#import "StopException.h"
#import "IOException.h"
#import "ParanoiaException.h"
#import "MissingResourceException.h"

#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close

// Tag values for NSPopupButton
enum {
	PARANOIA_LEVEL_FULL					= 0,
	PARANOIA_LEVEL_OVERLAP_CHECKING		= 1
};

@interface Ripper(Private)
- (BOOL)	logActivity;
- (void)	ripSectorRange:(SectorRange *)range toFile:(int)file;
@end

// cdparanoia callback
static char *callback_strings[15] = {
	"wrote",
	"finished",
	"read",
	"verify",
	"jitter",
	"correction",
	"scratch",
	"scratch repair",
	"skip",
	"drift",
	"backoff",
	"overlap",
	"dropped",
	"duped",
	"transport error"
};

static void 
callback(long inpos, int function, void *userdata)
{
	Ripper *ripper = (Ripper *)userdata;
	
	if([ripper logActivity]) {
		[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:[NSString stringWithFormat:@"Rip status: %s sector %ld (%ld)", (function >= -2 && function <= 13 ? callback_strings[function + 2] : ""), inpos / CD_FRAMEWORDS, inpos] waitUntilDone:NO];
	}	
}

@implementation Ripper

+ (void) initialize
{
	NSString				*paranoiaDefaultsValuesPath;
    NSDictionary			*paranoiaDefaultsValuesDictionary;
    
	@try {
		paranoiaDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ParanoiaDefaults" ofType:@"plist"];
		if(nil == paranoiaDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load ParanoiaDefaults.plist." userInfo:nil];
		}
		paranoiaDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:paranoiaDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:paranoiaDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) initWithSectors:(NSArray *)sectors drive:(cdrom_drive *)drive
{
	if((self = [super init])) {
		int paranoiaLevel	= 0;
		int paranoiaMode	= PARANOIA_MODE_DISABLE;
				
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"started"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"completed"];
		[self setValue:[NSNumber numberWithBool:NO] forKey:@"stopped"];
		
		// Setup logging
		_logActivity = [[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaEnableLogging"];
				
		// Setup cdparanoia
		_drive		= drive;
		_paranoia	= paranoia_init(_drive);

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaEnable"]) {
			paranoiaMode = PARANOIA_MODE_FULL ^ PARANOIA_MODE_NEVERSKIP; 
			
			paranoiaLevel = [[NSUserDefaults standardUserDefaults] integerForKey:@"paranoiaLevel"];
			
			if(PARANOIA_LEVEL_FULL == paranoiaLevel) {
			}
			else if(PARANOIA_LEVEL_OVERLAP_CHECKING == paranoiaLevel) {
				paranoiaMode |= PARANOIA_MODE_OVERLAP;
				paranoiaMode &= ~PARANOIA_MODE_VERIFY;
			}
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaNeverSkip"]) {
				paranoiaMode |= PARANOIA_MODE_NEVERSKIP;
				_maximumRetries = -1;
			}
			else {
				_maximumRetries = [[NSUserDefaults standardUserDefaults] integerForKey:@"paranoiaMaximumRetries"];
			}
		}
		else {
			paranoiaMode = PARANOIA_MODE_DISABLE;
		}

		paranoia_modeset(_paranoia, paranoiaMode);
		
		_sectors		= [sectors retain];
		
		// Determine the size of the track(s) we are ripping
		[self setValue:[_sectors valueForKeyPath:@"@sum.totalSectors"] forKey:@"grandTotalSectors"];
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	paranoia_free(_paranoia);

	[_sectors release];

	[_startTime release];
	[_endTime release];
	
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

- (BOOL) logActivity
{
	return _logActivity;
}

- (void) ripToFile:(int)file
{
	NSEnumerator		*enumerator;
	SectorRange			*range;
	
	// Tell our owner we are starting
	_startTime = [[NSDate date] retain];
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	enumerator = [_sectors objectEnumerator];
	
	while((range = [enumerator nextObject])) {
		[self ripSectorRange:range toFile:file];
		_sectorsRead = [NSNumber numberWithUnsignedLong:[_sectorsRead unsignedLongValue] + [range totalSectors]];
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	
	_endTime = [[NSDate date] retain];
}

- (void) ripSectorRange:(SectorRange *)range toFile:(int)file
{
	unsigned long		cursor				= [range firstSector];
	unsigned long		lastSector			= [range lastSector];
	int16_t				*buf				= NULL;
	unsigned long		grandTotalSectors	= [_grandTotalSectors unsignedLongValue];
	unsigned long		sectorsToRead		= grandTotalSectors - [_sectorsRead unsignedLongValue];
	long				where;
	
	// Go to the range's first sector in preparation for reading
	where = paranoia_seek(_paranoia, cursor, SEEK_SET);   	    
	if(-1 == where) {
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		@throw [ParanoiaException exceptionWithReason:@"Unable to access CD" userInfo:nil];
	}

	// Rip the track
	while(cursor <= lastSector) {
		
		// Check if we should stop, and if so throw an exception
		if([_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk
		buf = paranoia_read_limited(_paranoia, callback, self, (-1 == _maximumRetries ? 20 : _maximumRetries));
		if(NULL == buf) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [ParanoiaException exceptionWithReason:@"Skip tolerance exceeded/Unable to access CD" userInfo:nil];
		}
		
		// Update status
		sectorsToRead--;
		if(0 == sectorsToRead % 10) {
			[self setValue:[NSNumber numberWithDouble:((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) * 100.0] forKey:@"percentComplete"];
			NSTimeInterval interval = -1.0 * [_startTime timeIntervalSinceNow];
			unsigned int timeRemaining = interval / ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) - interval;
			[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
		}
		
		// Write data to file
		if(-1 == write(file, buf, CD_FRAMESIZE_RAW)) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		// Advance cursor
		++cursor;
	}
}

@end
