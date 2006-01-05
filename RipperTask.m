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


@implementation RipperTask

- (id) initWithTracks:(NSArray *)tracks metadata:(AudioMetadata *)metadata
{
	NSMutableArray		*sectors;
	SectorRange			*range;
	NSEnumerator		*enumerator;
	Track				*track;
	unsigned long		firstSector, lastSector;
	cdrom_drive			*drive;

	if(0 == [tracks count]) {
		@throw [NSException exceptionWithName:@"IllegalArgumentException" reason:@"Empty array passed to RipperTask::initWithTracks" userInfo:nil];
	}

	if((self = [super initWithMetadata:metadata])) {
		
		_tracks			= [tracks retain];
		drive			= [[[[_tracks objectAtIndex:0] getCompactDiscDocument] getDisc] getDrive];
		sectors			= [NSMutableArray arrayWithCapacity:[tracks count]];
		enumerator		= [_tracks objectEnumerator];
		
		while((track = [enumerator nextObject])) {
			[track setValue:[NSNumber numberWithBool:YES] forKey:@"ripInProgress"];

			firstSector		= [[track valueForKey:@"firstSector"] unsignedLongValue];
			lastSector		= [[track valueForKey:@"lastSector"] unsignedLongValue];
			range			= [SectorRange rangeWithFirstSector:firstSector lastSector:lastSector];

			[sectors addObject:range];
		}

		_ripper = [[Ripper alloc] initWithSectors:sectors drive:drive];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	NSEnumerator		*enumerator;
	Track				*track;

	enumerator = [_tracks objectEnumerator];		
	while((track = [enumerator nextObject])) {
		[track setValue:[NSNumber numberWithBool:NO] forKey:@"ripInProgress"];
	}

	[_tracks release];	
	[_ripper release];
	
	[super dealloc];
}

- (void) run:(id)object
{
	NSAutoreleasePool	*pool			= [[NSAutoreleasePool alloc] init];

	@try {
		[_ripper ripToFile:_out];
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:YES];
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
	[_ripper requestStop];
}

@end
