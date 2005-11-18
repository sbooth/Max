/*
 *  $Id: Ripper.h 64 2005-10-02 16:10:43Z me $
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

#import "RipperTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <paths.h>			//_PATH_TMP
#include <unistd.h>			// mkstemp, unlink

#define TEMPFILE_PATTERN	"MaxXXXXXX"

@implementation RipperTask

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"RipperTask::init called" userInfo:nil];
}

- (id) initWithDisc:(CompactDisc*) disc forTrack:(Track*) track trackName:(NSString*) trackName
{
	char *path = NULL;
	
	@try {
		if(self = [super init]) {
			
			[self setValue:trackName forKey:@"trackName"];
			
			// Create the output file
			path = malloc((strlen(_PATH_TMP) + strlen(TEMPFILE_PATTERN) + 1) *  sizeof(char));
			if(NULL == path) {
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			memcpy(path, _PATH_TMP, strlen(_PATH_TMP));
			memcpy(path + strlen(_PATH_TMP), TEMPFILE_PATTERN, strlen(TEMPFILE_PATTERN));
			
			_out = mkstemp(path);
			if(-1 == _out) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file. (%i:%s)", errno, strerror(errno)] userInfo:nil];
			}
			
			_path = [NSString stringWithUTF8String:path];
			
			_ripper = [[Ripper alloc] initWithDisc:disc forTrack:track];
			[_ripper addObserver:self forKeyPath:@"started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
			[_ripper addObserver:self forKeyPath:@"completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
			[_ripper addObserver:self forKeyPath:@"stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
			[_ripper addObserver:self forKeyPath:@"percentComplete" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
			[_ripper addObserver:self forKeyPath:@"timeRemaining" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		free(path);
	}
	
	return self;
}

- (void) dealloc
{
	close(_out);
	if(-1 == _out) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close the output file. (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}

	[_path release];
	
	[_ripper removeObserver:self forKeyPath:@"started"];
	[_ripper removeObserver:self forKeyPath:@"completed"];
	[_ripper removeObserver:self forKeyPath:@"stopped"];
	[_ripper removeObserver:self forKeyPath:@"percentComplete"];
	[_ripper removeObserver:self forKeyPath:@"timeRemaining"];

	[_ripper release];
	
	[super dealloc];
}

- (void) removeTemporaryFile
{
	if(-1 == unlink([_path UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete temporary file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}	
}

- (void) run:(id) object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try {
		[_ripper ripToFile:_out];		
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidStop:) withObject:self waitUntilDone:TRUE];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {
		[pool release];
	}
}

- (void) stop
{
	// If ripping has started request a stop
	if(YES == [[_ripper valueForKey:@"started"] boolValue]) {
		[_ripper setValue:[NSNumber numberWithBool:YES] forKey:@"shouldStop"];
	}
	// Otherwise remove it right away since it isn't running
	else {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidStop:) withObject:self waitUntilDone:TRUE];
	}
}

- (void) observeValueForKeyPath:(NSString*) keyPath ofObject:(id) object change:(NSDictionary*) change context:(void*) context
{
    if([keyPath isEqual:@"started"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidStart:) withObject:self waitUntilDone:TRUE];
    }
	else if([keyPath isEqual:@"completed"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidComplete:) withObject:self waitUntilDone:TRUE];
		[self setValue:[change objectForKey:NSKeyValueChangeNewKey] forKey:@"completed"];
	}
	else if([keyPath isEqual:@"stopped"]) {
		[self removeTemporaryFile];
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidStop:) withObject:self waitUntilDone:TRUE];
	}
	else if([keyPath isEqual:@"percentComplete"]) {
		[self setValue:[change objectForKey:NSKeyValueChangeNewKey] forKey:@"percentComplete"];
	}
	else if([keyPath isEqual:@"timeRemaining"]) {
		unsigned int timeRemaining = [[change objectForKey:NSKeyValueChangeNewKey] unsignedIntValue];
		[self setValue:[NSString stringWithFormat:@"%i:%02i", timeRemaining / 60, timeRemaining % 60] forKey:@"timeRemaining"];
	}
}

@end
