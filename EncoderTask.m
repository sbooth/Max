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
#import "EncoderMethods.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

@implementation EncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task outputFilename:(NSString *)outputFilename metadata:(AudioMetadata *)metadata
{
	if((self = [super init])) {
		_connection					= nil;
		_encoder					= nil;
		_task						= [task retain];
		_outputFilename				= [outputFilename retain];
		_metadata					= [metadata retain];
		_tracks						= nil;
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
		enumerator = [_tracks objectEnumerator];
	
		while((track = [enumerator nextObject])) {
			[track encodeCompleted];
			if(NO == [[track encodeInProgress] boolValue]) {
				[track setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
			}
		}

		[_tracks release];
	}
	
	if(nil != _connection) {
		[_connection release];
	}

	if(nil != _encoder) {
		[(NSObject *)_encoder release];
	}
	
	[_task release];
	[_outputFilename release];
	
	[super dealloc];
}

- (NSString *)		getOutputFilename				{ return _outputFilename; }
- (NSString *)		getPCMFilename					{ return [_task getOutputFilename]; }
- (NSArray *)		getTracks						{ return _tracks; }

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
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the output file", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}	
}

- (void) run
{
	NSPort		*port1			= [NSPort port];
	NSPort		*port2			= [NSPort port];
	NSArray		*portArray		= nil;
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted];
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_encoderClass withObject:portArray];
}

- (void) encoderReady:(id)anObject
{
	_encoder = [(NSObject*) anObject retain];
    [anObject setProtocolForProxy:@protocol(EncoderMethods)];
	[anObject encodeToFile:_outputFilename];
}

- (void) setStarted
{
	[super setStarted];
	[[TaskMaster sharedController] encodeDidStart:self]; 
}

- (void) setStopped 
{
	[super setStopped]; 
	[_connection invalidate];
	[[TaskMaster sharedController] encodeDidStop:self]; 
}

- (void) setCompleted 
{
	if(nil != _metadata) {
		[self writeTags];
	}

	[super setCompleted]; 
	[_connection invalidate];
	[[TaskMaster sharedController] encodeDidComplete:self]; 
}

- (void) stop
{
	if([self started]) {
		[self setShouldStop];
	}
	else {
		[_connection invalidate];
		[[TaskMaster sharedController] encodeDidStop:self];
	}
}

- (void)		writeTags						{}
- (NSString *)	description						{ return (nil == _metadata ? @"fnord" : [_metadata description]); }
- (NSString *)	settings						{ return (nil == _encoder ? @"fnord" : [_encoder settings]); }

@end
