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

#import "RipperTask.h"
#import "TaskMaster.h"
#import "SectorRange.h"
#import "IOException.h"
#import "StopException.h"

#include "cdparanoia/interface/cdda_interface.h"

@interface RipperTask (Private)
- (void) ripperReady:(id)anObject;
@end

@implementation RipperTask

- (id) initWithTracks:(NSArray *)tracks metadata:(AudioMetadata *)metadata
{
	SectorRange			*range;
	NSEnumerator		*enumerator;
	Track				*track;
	unsigned long		firstSector, lastSector;

	if(0 == [tracks count]) {
		@throw [NSException exceptionWithName:@"IllegalArgumentException" reason:@"Empty array passed to RipperTask::initWithTracks" userInfo:nil];
	}

	if((self = [super initWithMetadata:metadata])) {

		_connection		= nil;
		
		_tracks			= [tracks retain];
		_drive			= [[[[_tracks objectAtIndex:0] getCompactDiscDocument] getDisc] getDrive];
		_sectors		= [NSMutableArray arrayWithCapacity:[tracks count]];
		enumerator		= [_tracks objectEnumerator];
		
		while((track = [enumerator nextObject])) {
			firstSector		= [[track valueForKey:@"firstSector"] unsignedLongValue];
			lastSector		= [[track valueForKey:@"lastSector"] unsignedLongValue];
			range			= [SectorRange rangeWithFirstSector:firstSector lastSector:lastSector];

			[_sectors addObject:range];
		}

		[_sectors retain];
			
		return self;
	}
	return nil;
}

- (void) dealloc
{
	if(nil != _connection) {
		[_connection release];
	}
	
	[_sectors release];	
	[_tracks release];	
	
	[super dealloc];
}

- (NSArray *)			getSectors				{ return _sectors; }
- (NSString *)			getDeviceName			{ return [NSString stringWithUTF8String:_drive->device_name]; }
- (NSArray *)			getTracks				{ return _tracks; }

- (void) run
{
	NSEnumerator	*enumerator;
	Track			*track;
	NSPort			*port1			= [NSPort port];
	NSPort			*port2			= [NSPort port];
	NSArray			*portArray		= nil;
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted];
	
	enumerator = [_tracks objectEnumerator];		
	while((track = [enumerator nextObject])) {
		[track setValue:[NSNumber numberWithBool:YES] forKey:@"ripInProgress"];
	}
	
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:[Ripper class] withObject:portArray];
}

- (void) ripperReady:(id)anObject
{
    [anObject setProtocolForProxy:@protocol(RipperMethods)];
	[anObject ripToFile:_out];
}

- (void) setStarted
{
	[super setStarted];
	[[TaskMaster sharedController] ripDidStart:self]; 
}

- (void) setStopped 
{
	[super setStopped];
	[self closeOutputFile];
	[_connection invalidate];
	[[TaskMaster sharedController] ripDidStop:self]; 
}

- (void) setCompleted 
{
	NSEnumerator		*enumerator;
	Track				*track;

	[super setCompleted]; 
	[self closeOutputFile];
	[_connection invalidate];
	
	[[TaskMaster sharedController] ripDidComplete:self];
	
	enumerator = [_tracks objectEnumerator];		
	while((track = [enumerator nextObject])) {
		[track setValue:[NSNumber numberWithBool:NO] forKey:@"ripInProgress"];
	}
}

- (void) stop
{
	if([self started]) {
		[self setShouldStop];
	}
	else {
		[self closeOutputFile];
		[_connection invalidate];
		[[TaskMaster sharedController] ripDidStop:self];
	}
}

@end
