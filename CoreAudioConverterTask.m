/*
 *  $Id: RipperTask.m 205 2005-12-05 06:04:34Z me $
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

#import "CoreAudioConverterTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <paths.h>			//_PATH_TMP
#include <unistd.h>			// mkstemp, unlink

#define TEMPFILE_PATTERN	"MaxXXXXXX.raw"

@implementation CoreAudioConverterTask

- (id) initWithFilename:(NSString *)filename
{
	char				*path			= NULL;
	ssize_t				slashTmpLen		= strlen(_PATH_TMP);
	ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);
	
	if((self = [super init])) {
		@try {
			
			// Create and open the output file
			path = malloc((slashTmpLen + patternLen + 1) *  sizeof(char));
			if(NULL == path) {
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			memcpy(path, _PATH_TMP, slashTmpLen);
			memcpy(path + slashTmpLen, TEMPFILE_PATTERN, patternLen);
			path[slashTmpLen + patternLen] = '\0';
			
			_out = mkstemps(path, 4);
			if(-1 == _out) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			
			_path		= [[NSString stringWithUTF8String:path] retain];	
			_converter	= [[CoreAudioConverter alloc] initWithFilename:filename];
		}
		
		@catch(NSException *exception) {
			@throw;
		}
		
		@finally {
			free(path);
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	// Delete output file
	if(-1 == unlink([_path UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete temporary file '%@' (%i:%s)", _path, errno, strerror(errno)] userInfo:nil];
	}	
	
	[_path release];	
	[_converter release];
	
	[super dealloc];
}

- (NSString *) description
{
	return [[_converter valueForKey:@"filename"] lastPathComponent];
}

- (void) run:(id)object
{
	NSAutoreleasePool	*pool			= [[NSAutoreleasePool alloc] init];
	
	@try {
		[_converter convertToFile:_out];
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {		
		// Close output file
		if(-1 == close(_out)) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close the output file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		
		[pool release];
	}
}

- (void) stop
{
	[_converter requestStop];
}

@end
