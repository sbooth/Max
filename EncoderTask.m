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

#import "EncoderTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <paths.h>			//_PATH_TMP
#include <unistd.h>			// mkstemp

@implementation EncoderTask

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"EncoderTask::init called" userInfo:nil];
}

- (id) initWithSource:(NSString *) source target:(NSString *) target trackName:(NSString *) trackName;
{
	if(self = [super init]) {
		_target = [target retain];
		
		[self setValue:trackName forKey:@"trackName"];
		
		_encoder = [[Encoder alloc] initWithSource:source];
		[_encoder addObserver:self forKeyPath:@"started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
		[_encoder addObserver:self forKeyPath:@"completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
		[_encoder addObserver:self forKeyPath:@"stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
		[_encoder addObserver:self forKeyPath:@"percentComplete" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
		[_encoder addObserver:self forKeyPath:@"timeRemaining" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
	}
	return self;
}

- (void) dealloc
{
	[_target release];
	
	[_encoder removeObserver:self forKeyPath:@"started"];
	[_encoder removeObserver:self forKeyPath:@"completed"];
	[_encoder removeObserver:self forKeyPath:@"stopped"];
	[_encoder removeObserver:self forKeyPath:@"percentComplete"];
	[_encoder removeObserver:self forKeyPath:@"timeRemaining"];
	
	[_encoder release];
	
	[super dealloc];
}

- (void) removeOutputFile
{
	if(-1 == unlink([_target UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}	
}

- (void) run:(id) object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try {
		[_encoder encodeToFile:_target];		
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStop:) withObject:self waitUntilDone:TRUE];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {
		[pool release];
	}
}

- (void) stop
{
	// If encoding has started request a stop
	if(YES == [[_encoder valueForKey:@"started"] boolValue]) {
		[_encoder setValue:[NSNumber numberWithBool:YES] forKey:@"shouldStop"];
	}
	// Otherwise remove it right away since it isn't running
	else {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStop:) withObject:self waitUntilDone:TRUE];
	}
}

- (void) observeValueForKeyPath:(NSString *) keyPath ofObject:(id) object change:(NSDictionary *) change context:(void *) context
{
    if([keyPath isEqual:@"started"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStart:) withObject:self waitUntilDone:TRUE];
    }
	else if([keyPath isEqual:@"completed"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidComplete:) withObject:self waitUntilDone:TRUE];
		[self setValue:[change objectForKey:NSKeyValueChangeNewKey] forKey:@"completed"];
	}
	else if([keyPath isEqual:@"stopped"]) {
		[self removeOutputFile];
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"stopped"];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStop:) withObject:self waitUntilDone:TRUE];
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
