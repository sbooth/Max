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
#import "IOException.h"

#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close

@implementation Ripper

- (id) initWithDisc:(CompactDisc *)disc forTrack:(Track *)track;
{
	_buf	= NULL;
	
	if(self = [super init]) {
		
		@try {
			_disc	= [disc retain];
			_track	= [track retain];
			
			// Open the disc for reading
			_fd = open([[_disc valueForKey:@"bsdPath"] UTF8String], O_RDONLY);
			if(-1 == _fd) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			// Allocate the buffer
			_blockSize		= [[_disc valueForKey: @"preferredBlockSize"] unsignedIntValue];
			_bufsize		= 512 * _blockSize;
			_buf			= (unsigned char*) calloc(_bufsize, sizeof(unsigned char));
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
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	
	free(_buf);
	
	[_disc release];
	[_track release];
	
	[super dealloc];
}

- (NSData *) get
{
	ssize_t bytesRead;
	
	bytesRead = read(_fd, _buf, (_bytesToRead > _bufsize ? _bufsize : _bytesToRead));
	if(-1 == bytesRead) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to access CD (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}

	_bytesToRead -= bytesRead;
	
	return [NSData dataWithBytesNoCopy:_buf length:bytesRead freeWhenDone:NO];
}

- (ssize_t) bytesRemaining										{ return _bytesToRead; }
- (double) percentRead											{ return ((double)(_totalBytes - _bytesToRead)/(double) _totalBytes) * 100.0; }

@end
