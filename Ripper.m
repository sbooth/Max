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

#import "Ripper.h"
#import "RipperTask.h"
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
		[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip status: %s sector %ld (%ld)", @"Log", @""), (function >= -2 && function <= 13 ? callback_strings[function + 2] : ""), inpos / CD_FRAMEWORDS, inpos] waitUntilDone:NO];
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
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"ParanoiaDefaults.plist" forKey:@"filename"]];
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

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool	*pool				= nil;
	NSConnection		*connection			= nil;
	Ripper				*ripper				= nil;
	RipperTask			*owner				= nil;
	
	@try {
		pool			= [[NSAutoreleasePool alloc] init];
		connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
		owner			= (RipperTask *)[connection rootProxy];
		ripper			= [[self alloc] initWithSectors:[owner sectors] deviceName:[owner deviceName]];

		[ripper setDelegate:owner];
		[owner ripperReady:ripper];
		
		[ripper release];

		[[NSRunLoop currentRunLoop] run];
	}	
	
	@catch(NSException *exception) {
		if(nil != owner) {
			[owner setException:exception];
			[owner setStopped];
		}
	}

	@finally {
		if(nil != pool) {
			[pool release];
		}		
	}
}

- (id) initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName
{
	if((self = [super init])) {
		int paranoiaLevel	= 0;
		int paranoiaMode	= PARANOIA_MODE_DISABLE;

		// Setup logging
		_logActivity = [[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaEnableLogging"];
		
		// Setup cdparanoia
		_drive		= cdda_identify([deviceName UTF8String], 0, NULL);
		if(NULL == _drive) {
			@throw [ParanoiaException exceptionWithReason:NSLocalizedStringFromTable(@"cdda_identify failed", @"Exceptions", @"") userInfo:nil];
		}
		
		if(0 != cdda_open(_drive)) {
			@throw [ParanoiaException exceptionWithReason:NSLocalizedStringFromTable(@"cdda_open failed", @"Exceptions", @"") userInfo:nil];
		}
		
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
	cdda_close(_drive);
	paranoia_free(_paranoia);

	[_sectors release];

	[super dealloc];
}

- (BOOL)				logActivity									{ return _logActivity; }

- (void)				setDelegate:(id <TaskMethods>)delegate		{ _delegate = delegate; }
- (id <TaskMethods>)	delegate									{ return _delegate; }

- (oneway void) ripToFile:(NSString *)filename
{
	int					fd;
	NSEnumerator		*enumerator;
	SectorRange			*range;
	
	// Tell our owner we are starting
	_startTime = [NSDate date];
	[_delegate setStartTime:_startTime];
	[_delegate setStarted];

	@try {
		// Open the output file
		fd = open([filename UTF8String], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		enumerator = [_sectors objectEnumerator];
		
		while((range = [enumerator nextObject])) {
			[self ripSectorRange:range toFile:fd];
			_sectorsRead = [NSNumber numberWithUnsignedLong:[_sectorsRead unsignedLongValue] + [range totalSectors]];
		}
	}

	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		// Close the output file
		if(-1 == close(fd)) {
			NSException *exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
															 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) ripSectorRange:(SectorRange *)range toFile:(int)file
{
	unsigned long		cursor				= [range firstSector];
	unsigned long		lastSector			= [range lastSector];
	int16_t				*buf				= NULL;
	unsigned long		grandTotalSectors	= [_grandTotalSectors unsignedLongValue];
	unsigned long		sectorsToRead		= grandTotalSectors - [_sectorsRead unsignedLongValue];
	long				where;
	unsigned long		iterations			= 0;
	
	// Go to the range's first sector in preparation for reading
	where = paranoia_seek(_paranoia, cursor, SEEK_SET);   	    
	if(-1 == where) {
		[_delegate setStopped];
		@throw [ParanoiaException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to access CD", @"Exceptions", @"") userInfo:nil];
	}

	// Rip the track
	while(cursor <= lastSector) {
		
		// Read a chunk
		buf = paranoia_read_limited(_paranoia, callback, self, (-1 == _maximumRetries ? 20 : _maximumRetries));
		if(NULL == buf) {
			@throw [ParanoiaException exceptionWithReason:NSLocalizedStringFromTable(@"CD skip tolerance exceeded", @"Exceptions", @"") userInfo:nil];
		}
		
		// Write data to file
		if(-1 == write(file, buf, CD_FRAMESIZE_RAW)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Update status
		sectorsToRead--;
		
		// Distributed Object calls are expensive, so only perform them every few iterations
		if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
			
			// Check if we should stop, and if so throw an exception
			if([_delegate shouldStop]) {
				@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
			}
			
			// Update UI
			double percentComplete = ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) * 100.0;
			NSTimeInterval interval = -1.0 * [_startTime timeIntervalSinceNow];
			unsigned int secondsRemaining = interval / ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) - interval;
			NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
			
			[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
		}
		
		++iterations;

		// Advance cursor
		++cursor;
	}
}

- (NSString *) deviceName
{
	return [NSString stringWithUTF8String:_drive->device_name];
}

@end
