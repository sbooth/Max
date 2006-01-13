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

#import "EncoderTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

@implementation EncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task outputFilename:(NSString *)outputFilename metadata:(AudioMetadata *)metadata
{
	if((self = [super init])) {
		_task						= [task retain];
		_outputFilename				= [outputFilename retain];
		_metadata					= [metadata retain];
		_tracks						= nil;
		_encoder					= nil;
		_writeSettingsToComment		= [[NSUserDefaults standardUserDefaults] boolForKey:@"saveEncoderSettingsInComment"];
			
		return self;
	}
	return nil;
}

- (void) dealloc
{
	NSEnumerator	*enumerator;
	Track			*track;

	if(nil != _tracks) {
		enumerator		= [_tracks objectEnumerator];
	
		while((track = [enumerator nextObject])) {
			[track encodeCompleted];
			if(NO == [[track encodeInProgress] boolValue]) {
				[track setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
			}
		}

		[_tracks release];
	}
	
	[_task release];
	[_outputFilename release];
	
	[super dealloc];
}

- (void) setTracks:(NSArray *)tracks
{
	NSEnumerator	*enumerator;
	Track			*track;

	if(nil != _tracks) {
		[_tracks release];
	}
	
	_tracks			= [tracks retain];
	enumerator		= [_tracks objectEnumerator];
	
	while((track = [enumerator nextObject])) {
		[track encodeStarted];
	}
}

- (void) removeOutputFile
{
	if(-1 == unlink([_outputFilename UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}	
}

- (void) run:(id) object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	@try {
		[[TaskMaster sharedController] encodeDidStart:self];
		[_encoder setDelegate:self];
		[_encoder encodeToFile:_outputFilename];
		if(nil != _metadata) {
			[self writeTags];
		}
		[[TaskMaster sharedController] encodeDidComplete:self];
	}
	
	@catch(StopException *exception) {
		[[TaskMaster sharedController] encodeDidStop:self];
		[self removeOutputFile];
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] encodeDidStop:self];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:NO];
	}
	
	@finally {
		[[TaskMaster sharedController] encodeFinished:self];
		[pool release];
	}
}

- (void) stop
{
	if([_started boolValue]) {
		_shouldStop = [NSNumber numberWithBool:YES];			
	}
	else {
		[[TaskMaster sharedController] encodeDidStop:self];
		[[TaskMaster sharedController] encodeFinished:self];
	}
}

- (void)		writeTags						{}
- (NSString *)	description						{ return (nil == _metadata ? @"fnord" : [_metadata description]); }
- (NSString *)	getType							{ return nil; }

@end
