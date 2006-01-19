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

#import "ConverterMethods.h"
#import "ConverterTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

@interface ConverterTask (Private)
- (void) converterReady:(id)anObject;
@end

@implementation ConverterTask

- (id) initWithInputFilename:(NSString *)inputFilename metadata:(AudioMetadata *)metadata
{
	if((self = [super initWithMetadata:metadata])) {
		_inputFilename	= [inputFilename retain];
		_connection		= nil;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	if(nil != _connection) {
		[_connection release];
	}
	
	[_inputFilename release];	
	[super dealloc];
}

- (NSString *) description 
{
	NSString *description = [_metadata description];
	
	if([description isEqualToString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"")]) {
		return [_inputFilename lastPathComponent]; 
	}
	else {
		return [[description retain] autorelease];
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
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_converterClass withObject:portArray];
}

- (void) converterReady:(id)anObject
{
    [anObject setProtocolForProxy:@protocol(ConverterMethods)];
	[anObject convertToFile:_out];
}

- (void) setStarted
{
	[super setStarted];
	[[TaskMaster sharedController] convertDidStart:self]; 
}

- (void) setStopped 
{
	[super setStopped]; 
	[self closeOutputFile];
	[_connection invalidate];
	[[TaskMaster sharedController] convertDidStop:self]; 
}

- (void) setCompleted 
{
	[super setCompleted]; 
	[self closeOutputFile]; 
	[_connection invalidate];
	[[TaskMaster sharedController] convertDidComplete:self]; 
}

- (void) stop
{
	if([self started]) {
		[self setShouldStop];
	}
	else {
		[self closeOutputFile];
		[_connection invalidate];
		[[TaskMaster sharedController] convertDidStop:self];
	}
}

- (NSString *)	getInputFilename				{ return _inputFilename; }

@end
