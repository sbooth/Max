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

#import "SpeexConverter.h"

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation SpeexConverter

- (id) initWithInputFilename:(NSString *)inputFilename
{
	if((self = [super initWithInputFilename:inputFilename])) {

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[super dealloc];
}

- (void) convertToFile:(int)file
{
	NSDate						*startTime			= [NSDate date];
	
	// Tell our owner we are starting
	[_delegate setValue:startTime forKey:@"startTime"];	
	[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"started"];
	[_delegate setValue:[NSNumber numberWithDouble:0.0] forKey:@"percentComplete"];
	
	
	[_delegate setValue:[NSDate date] forKey:@"endTime"];
	[_delegate setValue:[NSNumber numberWithDouble:100.0] forKey:@"percentComplete"];
	[_delegate setValue:[NSNumber numberWithBool:YES] forKey:@"completed"];	
}

@end
