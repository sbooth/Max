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

#include <cdparanoia/cdda_interface.h>

@interface RipperTask (Private)
- (void) generateCueSheet;
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
		_deviceName		= [[[[_tracks objectAtIndex:0] getCompactDiscDocument] getDisc] deviceName];
		_sectors		= [NSMutableArray arrayWithCapacity:[tracks count]];
		enumerator		= [_tracks objectEnumerator];
		
		while((track = [enumerator nextObject])) {
			[track setValue:[NSNumber numberWithBool:YES] forKey:@"ripInProgress"];

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

- (NSArray *)			sectors				{ return _sectors; }
- (NSString *)			deviceName			{ return _deviceName; }
- (NSArray *)			tracks				{ return _tracks; }

- (void) run
{
	NSPort			*port1			= [NSPort port];
	NSPort			*port2			= [NSPort port];
	NSArray			*portArray		= nil;
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted];
	
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:[Ripper class] withObject:portArray];
}

- (void) ripperReady:(id)anObject
{
    [anObject setProtocolForProxy:@protocol(RipperMethods)];
	[self touchOutputFile];
	[anObject ripToFile:[self outputFilename]];
}

- (void) setStarted
{
	[super setStarted];
	[[TaskMaster sharedController] ripDidStart:self]; 
}

- (void) setStopped 
{
	NSEnumerator		*enumerator;
	Track				*track;

	[super setStopped];
	[_connection invalidate];
	[[TaskMaster sharedController] ripDidStop:self]; 

	enumerator = [_tracks objectEnumerator];		
	while((track = [enumerator nextObject])) {
		[track setValue:[NSNumber numberWithBool:NO] forKey:@"ripInProgress"];
	}
}

- (void) setCompleted 
{
	NSEnumerator		*enumerator;
	Track				*track;

	[super setCompleted];
	[_connection invalidate];
	
	[[TaskMaster sharedController] ripDidComplete:self];
	
	enumerator = [_tracks objectEnumerator];		
	while((track = [enumerator nextObject])) {
		[track setValue:[NSNumber numberWithBool:NO] forKey:@"ripInProgress"];
	}
}

- (void) stop
{
	if([self started] && NO == [self stopped]) {
		[self setShouldStop];
	}
	else {
		[self setStopped];
	}
}

- (void) generateCueSheet
{
	
}

@end
