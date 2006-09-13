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

#import "FileReader.h"

#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

@implementation FileReader

+ (id) fileReaderForFilename:(NSString *)filename
{
	FileReader		*result		= nil;
	
	result = [[FileReader alloc] initWithFilename:filename];
	
	return [result autorelease];
}

- (id) initWithFilename:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
	if((self = [super init])) {
		_filename = [filename retain];
		
		_fd = open([filename fileSystemRepresentation], O_RDONLY);
		NSAssert2(-1 != _fd, @"Unable to open file %@ for reading: %s", filename, strerror(errno));
		
		return self;
	}
	return nil;
}

- (void) dealloc
{	
	int		result;
	
	[_filename release];	_filename = nil;
	
	result	= close(_fd);
	_fd		= -1;
	NSAssert1(-1 != result, @"Unable to close file: %s", strerror(errno));
	
	[super dealloc];
}

- (off_t)			totalBytes
{
	struct stat		sb;
	int				result;

	result = fstat(_fd, &sb);
	NSAssert1(-1 != result, @"Unable to get file statistics: %s", strerror(errno));
	
	return sb.st_size;
}

- (NSString *)		filename									{ return [[_filename retain] autorelease]; }

- (BOOL)			isSeekable									{ return YES; }
- (off_t)			currentOffset								{ return [self seekToOffset:0 seekType:kReaderSeekTypeCurrent]; }

- (off_t)			seekToOffset:(off_t)offset seekType:(ReaderSeekType)seekType
{
	int			type;
	off_t		newOffset;
	
	switch(seekType) {
		case kReaderSeekTypeAbsolute:		type = SEEK_SET;		break;
		case kReaderSeekTypeCurrent:		type = SEEK_CUR;		break;
		case kReaderSeekTypeEnd:			type = SEEK_END;		break;
		default:							type = SEEK_SET;		break;
	}

	newOffset = lseek(_fd, offset, type);
	NSAssert1(-1 != newOffset, @"Unable to seek in file: %s", strerror(errno));
	
	return newOffset;
}

- (ssize_t)			readData:(void *)buffer byteCount:(size_t)byteCount
{
	ssize_t		bytesRead;
	
	bytesRead = read(_fd, buffer, byteCount);
	NSAssert1(-1 != bytesRead, @"Unable to read from file: %s", strerror(errno));
	
	return bytesRead;
}

@end
