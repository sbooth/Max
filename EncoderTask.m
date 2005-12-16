/*
 *  $Id: EncoderTask.m 183 2005-11-30 05:36:21Z me $
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

@implementation EncoderTask

- (id) initWithOutputFilename:(NSString *)outputFilename metadata:(AudioMetadata *)metadata
{
	if((self = [super init])) {
		_outputFilename			= [outputFilename retain];
		_tracks					= nil;
		_metadata				= [metadata retain];
		_writeSettingsToComment = [[NSUserDefaults standardUserDefaults] boolForKey:@"saveEncoderSettingsInComment"];
			
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

- (NSString *) description
{
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
		[_encoder encodeToFile:_outputFilename];
		if(nil != _metadata) {
			[self writeTags];
		}
	}
	
	@catch(StopException *exception) {
		[self removeOutputFile];
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {
		[pool release];
	}
}

- (void) stop									{ [_encoder requestStop]; }
- (void) writeTags								{}
- (NSString *) getType							{ return nil; }

@end
