/*
 *  $Id: RipperTask.m 205 2005-12-05 06:04:34Z me $
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
#import "SectorRange.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include "cdparanoia/interface/cdda_interface.h"

#include <paths.h>			//_PATH_TMP
#include <unistd.h>			// mkstemp, unlink

#define TEMPFILE_PATTERN	"MaxXXXXXX.raw"

@implementation RipperTask

- (id) initWithTracks:(NSArray *)tracks
{
	NSMutableArray		*sectors;
	SectorRange			*range;
	NSEnumerator		*enumerator;
	Track				*track;
	unsigned long		firstSector, lastSector;
	cdrom_drive			*drive;
	char				*path			= NULL;
	ssize_t				slashTmpLen		= strlen(_PATH_TMP);
	ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);

	if(0 == [tracks count]) {
		@throw [NSException exceptionWithName:@"IllegalArgumentException" reason:@"empty array passed to RipperTask::initWithTracks" userInfo:nil];
	}

	if((self = [super init])) {
		@try {
			
			// Create and open the output file
			path = malloc((slashTmpLen + patternLen + 1) *  sizeof(char));
			if(NULL == path) {
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			memcpy(path, _PATH_TMP, slashTmpLen);
			memcpy(path + slashTmpLen, TEMPFILE_PATTERN, patternLen);
			path[slashTmpLen + patternLen] = '\0';
			
			_out = mkstemps(path, 4);
			if(-1 == _out) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			
			_tracks			= [tracks retain];
			_path			= [[NSString stringWithUTF8String:path] retain];
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
		}
		
		@catch(NSException *exception) {
			@throw;
		}
		
		@finally {
			free(path);
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	// Delete output file
	if(-1 == unlink([_path UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete temporary file '%@' (%i:%s)", _path, errno, strerror(errno)] userInfo:nil];
	}	

	[_tracks release];	
	[_path release];	
	[_ripper release];
	
	[super dealloc];
}

- (NSString *) description
{
	if(1 == [_tracks count]) {
		return [[_tracks objectAtIndex:0] description];
	}
	else {
		return @"Multiple tracks";
	}
}

- (void) run:(id)object
{
	NSAutoreleasePool	*pool			= [[NSAutoreleasePool alloc] init];
	NSEnumerator		*enumerator;
	Track				*track;

	@try {
		[_ripper ripToFile:_out];
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
	}
	
	@finally {
		enumerator = [_tracks objectEnumerator];		
		while((track = [enumerator nextObject])) {
			[track setValue:[NSNumber numberWithBool:NO] forKey:@"ripInProgress"];
		}

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
