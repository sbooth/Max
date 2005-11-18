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

- (id) initWithDisc:(CompactDisc *) disc forTrack:(Track *) track
{
	_buf = NULL;
	
	if(self = [super init]) {
		
		@try {
			_disc	= [disc retain];
			_track	= [track retain];
			
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"started"];
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"completed"];
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"stopped"];
			[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];

			// Open the disc for reading
			_fd = open([[_disc valueForKey:@"bsdPath"] UTF8String], O_RDONLY);
			if(-1 == _fd) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			// Allocate the buffer
			_blockSize		= [[_disc valueForKey: @"preferredBlockSize"] unsignedIntValue];
			_bufsize		= 1024 * _blockSize;
			_buf			= (unsigned char *) calloc(_bufsize, sizeof(unsigned char));
			if(NULL == _buf) {
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			// Determine the size of the track we are ripping
			_firstSector	= [[_track getFirstSector] unsignedIntValue];
			_lastSector		= [[_track valueForKey:@"lastSector"] unsignedIntValue];
			_totalBytes		= (_lastSector - _firstSector) * _blockSize;
			_bytesToRead	= _totalBytes;

			// Go to the track's first sector in preparation for reading
			off_t where = lseek(_fd, _firstSector * _blockSize, SEEK_SET);
			if(-1 == where) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
		}
		
		@catch(NSException *exception) {
			free(_buf);
			close(_fd);
			@throw;
		}
		
		@finally {
		}
	}
	return self;
}

- (void) dealloc
{
	if(-1 == close(_fd)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	free(_buf);
	
	[_disc release];
	[_track release];
	
	[super dealloc];
}

- (void) ripToFile:(int) file
{
	ssize_t bytesRead;

	// Tell our owner we are starting
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[self setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];

	_startTime = [NSDate date];
	
	while(0 < _bytesToRead) {

		// Check if we should stop, and if so throw an exception
		if(YES == [_shouldStop boolValue]) {
			[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Read a chunk
		bytesRead = read(_fd, _buf, (_bytesToRead > _bufsize ? _bufsize : _bytesToRead));
		if(-1 == bytesRead) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		
		// Update status
		_bytesToRead -= bytesRead;
		[self setValue:[NSNumber numberWithDouble:((double)(_totalBytes - _bytesToRead)/(double) _totalBytes) * 100.0] forKey:@"percentComplete"];
		NSTimeInterval interval = -1.0 * [_startTime timeIntervalSinceNow];
		[self setValue:[NSNumber numberWithDouble:(interval / ((double)(_totalBytes - _bytesToRead)/(double) _totalBytes) - interval)] forKey:@"timeRemaining"];
		
		// Write data to file
		if(-1 == write(file, _buf, bytesRead)) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
	}
	
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];
	[self setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
}

@end
