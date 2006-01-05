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

#import "ConverterTask.h"
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

@implementation ConverterTask

- (id) initWithInputFilename:(NSString *)inputFilename metadata:(AudioMetadata *)metadata
{
	if((self = [super initWithMetadata:metadata])) {
		_inputFilename		= [inputFilename retain];
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_inputFilename release];	
	[super dealloc];
}

- (NSString *) description 
{ 
	NSString *description = [_metadata description];
	
	if([description isEqualToString:@"Unknown Track"]) {
		return [_inputFilename lastPathComponent]; 
	}
	else {
		return [[description retain] autorelease];
	}
}

- (void) run:(id)object
{
	NSAutoreleasePool	*pool			= [[NSAutoreleasePool alloc] init];
	
	@try {
		[_converter convertToFile:_out];
	}
	
	@catch(StopException *exception) {
	}
	
	@catch(NSException *exception) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(displayExceptionSheet:) withObject:exception waitUntilDone:TRUE];
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
	[_converter requestStop];
}

@end
