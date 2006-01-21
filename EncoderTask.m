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
#import "UtilityFunctions.h"

@interface EncoderTask (Private)
- (void) touchOutputFile;
@end

@implementation EncoderTask

- (id) initWithTask:(PCMGeneratingTask *)task
{
	if((self = [super init])) {
		_connection					= nil;
		_encoder					= nil;
		_task						= [task retain];
		_outputFilename				= nil;
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
	
	if(nil != _outputFilename) {
		[_outputFilename release];
	}	

	[_task release];
	
	[super dealloc];
}

- (NSString *)		outputFilename					{ return _outputFilename; }
- (NSString *)		inputFilename					{ return [_task outputFilename]; }
- (NSString *)		outputFormat					{ return nil; }
- (NSArray *)		tracks							{ return _tracks; }
- (NSString *)		extension						{ return nil; }
- (void)			writeTags						{}
- (NSString *)		description						{ return (nil == [_task metadata] ? @"fnord" : [[_task metadata] description]); }
- (NSString *)		settings						{ return (nil == _encoder ? @"fnord" : [_encoder settings]); }

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
	if(nil != _outputFilename && -1 == unlink([_outputFilename UTF8String])) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the output file", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}	
}

- (void) touchOutputFile
{
	int fd;
	
	if(nil != _outputFilename) {
		// Create the file (don't overwrite)
		fd = open([_outputFilename UTF8String], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// And close it
		if(-1 == close(fd)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}	
}

- (void) run
{
	NSString				*basename;
	NSMutableDictionary		*substitutions		= [NSMutableDictionary dictionaryWithCapacity:1];
	NSPort					*port1				= [NSPort port];
	NSPort					*port2				= [NSPort port];
	NSArray					*portArray			= nil;
	
	// Set up the additional key/value pairs to be substituted
	[substitutions setObject:[self outputFormat] forKey:@"fileFormat"];
	basename = [[_task metadata] outputBasenameWithSubstitutions:substitutions];

	// Create the directory hierarchy if required
	createDirectoryStructure(basename);
	
	// Generate a unique filename and touch the file
	_outputFilename = [generateUniqueFilename(basename, [self extension]) retain];
	[self touchOutputFile];
	
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
	[anObject encodeToFile:[self outputFilename]];
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
	if(nil != [_task metadata]) {
		[self writeTags];
	}

	[super setCompleted]; 
	[_connection invalidate];
	[[TaskMaster sharedController] encodeDidComplete:self]; 

	// Delete input file if requested
	if([_task isKindOfClass:[ConverterTask class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"deleteAfterConversion"]) {
		if(-1 == unlink([[(ConverterTask *)_task inputFilename] UTF8String])) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the input file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}	
	}
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

@end
