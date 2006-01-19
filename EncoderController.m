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

#import "EncoderController.h"

#import "TaskMaster.h"
#import "IOException.h"

#include <sys/param.h>		// statfs
#include <sys/mount.h>

static EncoderController *sharedController = nil;

@interface EncoderController (Private)
- (void) updateFreeSpace:(NSTimer *)theTimer;
@end

@implementation EncoderController

- (id) init
{
	if((self = [super initWithWindowNibName:@"Encoder"])) {

		_timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateFreeSpace:) userInfo:nil repeats:YES];

		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_timer invalidate];
	[super dealloc];
}

- (void) awakeFromNib
{
	[_taskTable setAutosaveTableColumns:YES];
}

+ (EncoderController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController) {
			sharedController = [[self alloc] init];
		}
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            return [super allocWithZone:zone];
        }
    }
    return sharedController;
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (unsigned)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void)		release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Encoder"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) updateFreeSpace:(NSTimer *)theTimer
{
	struct statfs			buf;
	unsigned long long		bytesFree;
	long double				freeSpace;
	unsigned				divisions;
	
	if(-1 == statfs([[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] UTF8String], &buf)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to get file system statistics (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
	}
	
	bytesFree	= (unsigned long long) buf.f_bsize * (unsigned long long) buf.f_bfree;
	freeSpace	= (long double) bytesFree;
	divisions	= 0;
	
	while(1024 < freeSpace) {
		freeSpace /= 1024;
		++divisions;
	}
	
	switch(divisions) {
		case 0:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f B", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 1:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f KB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 2:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f MB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 3:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f GB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 4:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f TB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
		case 5:	[self setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"%.2f PB", @"General", @""), freeSpace] forKey:@"freeSpace"];	break;
	}
}

@end
