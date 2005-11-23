/*
 *  $Id$
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

#import "MediaController.h"
#import "IOException.h"

#import "CompactDiscController.h"

#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/storage/IOCDMedia.h>
#include <IOKit/storage/IOCDTypes.h>

#include <paths.h>			// _PATH_DEV
#include <sys/param.h>		// MAXPATHLEN


// ==================================================
// From Apple's CDROMSample.c
// ==================================================
static kern_return_t 
findEjectableCDMedia(io_iterator_t *mediaIterator)
{
    kern_return_t				kernResult; 
    mach_port_t					masterPort;
    CFMutableDictionaryRef		classesToMatch;
	
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if(KERN_SUCCESS != kernResult) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"IOMasterPort returned %d", kernResult] userInfo:nil];
    }
	
    classesToMatch = IOServiceMatching(kIOCDMediaClass); 
    if(NULL == classesToMatch) {
		@throw [IOException exceptionWithReason:@"IOServiceMatching returned a NULL dictionary." userInfo:nil];
    }
    else {
		CFDictionarySetValue(classesToMatch, CFSTR(kIOMediaEjectableKey), kCFBooleanTrue); 
    }
    
    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, mediaIterator);    
    if(KERN_SUCCESS != kernResult) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"IOServiceGetMatchingServices returned %d", kernResult] userInfo:nil];
    }
    
    return kernResult;
}
// ==================================================
// End Apple code
// ==================================================

static NSString *
getBSDName(io_object_t media)
{
	char			bsdPath[ MAXPATHLEN ];
	ssize_t			devPathLength;
	CFTypeRef		deviceNameAsCFString;
	
	@try {
		/* Get the BSD path for the device */
		deviceNameAsCFString = IORegistryEntryCreateCFProperty(media, CFSTR(kIOBSDNameKey), kCFAllocatorDefault, 0);
		if(NULL == deviceNameAsCFString) {
			@throw [IOException exceptionWithReason:@"IORegistryEntryCreateCFProperty returned NULL." userInfo:nil];
		}
		
		strcpy(bsdPath, _PATH_DEV);
		
		/* Add "r" before the BSD node name from the I/O Registry to specify the raw disk
			node. The raw disk nodes receive I/O requests directly and do not go through
			the buffer cache. */	
		strcat(bsdPath, "r");
		
		devPathLength = strlen(bsdPath);
		
		if(FALSE == CFStringGetCString(deviceNameAsCFString, bsdPath + devPathLength, MAXPATHLEN - devPathLength, kCFStringEncodingASCII)) {
			@throw [IOException exceptionWithReason:@"CFStringGetCString returned FALSE." userInfo:nil];
		}
	}
	
	@catch(NSException *exception) {
		@throw;
	}

	@finally {
		CFRelease(deviceNameAsCFString);
	}

	return [NSString stringWithUTF8String:(const char *)bsdPath];
}

static MediaController *sharedMedia = nil;

@implementation MediaController

+ (MediaController *) sharedMedia
{
	@synchronized(self) {
		if(nil == sharedMedia) {
			sharedMedia = [[self alloc] init];
		}
	}
	return sharedMedia;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedMedia) {
            return [super allocWithZone:zone];
        }
    }
    return sharedMedia;
}

- (id) init
{
	NSNotificationCenter	*notificationCenter;

	if((self = [super init])) {

		// Array of controllers for all mounted CDs
		_media = [[NSMutableArray alloc] initWithCapacity:3];
				
		// Register to receive mount/unmount notifications
		notificationCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
		[notificationCenter addObserver:self selector:@selector(volumeMounted:) name:@"NSWorkspaceDidMountNotification" object:nil];
		[notificationCenter addObserver:self selector:@selector(volumeUnmounted:) name:@"NSWorkspaceWillUnmountNotification" object:nil];		
	}
	return self;
}

- (void) dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	
	[_media release];

	[super dealloc];
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void) scanForMedia
{
	// First show any windows that might have been closed
	NSEnumerator *enumerator = [_media objectEnumerator];
	CompactDiscController *object;
	while((object = [enumerator nextObject])) {
		[[object valueForKey:@"window"] makeKeyAndOrderFront:nil];
	}

	// Now look for new devices
	[self volumeMounted:nil];
}

// We don't actually use the notification, it is just a convenient hook
- (void) volumeMounted: (NSNotification *) notification
{
	kern_return_t	kernResult;
	io_iterator_t	mediaIterator;
	io_object_t		nextMedia;
	BOOL			found;
	
	kernResult = findEjectableCDMedia(&mediaIterator);
	
	while((nextMedia = IOIteratorNext(mediaIterator))) {
		NSEnumerator			*enumerator		= [_media objectEnumerator];
		CompactDiscController	*object			= nil;
		NSString				*bsdName		= getBSDName(nextMedia);

		found = FALSE;
		
		while((object = [enumerator nextObject])) {
			if([bsdName isEqualToString:[[[object valueForKey:@"disc"] valueForKey:@"drive"] valueForKey:@"bsdName"]]) {
				found = TRUE;
				break;
			}
		}
		if(FALSE == found) {
			CompactDiscController *controller = [[CompactDiscController alloc] initWithDisc:[[CompactDisc alloc] initWithBSDName:bsdName]];
			[_media addObject: controller];
		}				
	}
	
	kernResult = IOObjectRelease(mediaIterator);
    if(KERN_SUCCESS != kernResult) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"IOObjectRelease returned %d", kernResult] userInfo:nil];
    }
}

// We don't actually use the notification, it is just a convenient hook
- (void) volumeUnmounted: (NSNotification *) notification
{
	kern_return_t	kernResult;
	io_iterator_t	mediaIterator;
	io_object_t		nextMedia;
	
	kernResult = findEjectableCDMedia(&mediaIterator);
    if(KERN_SUCCESS != kernResult) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"findEjectableCDMedia returned %d", kernResult] userInfo:nil];
    }
	
	while((nextMedia = IOIteratorNext(mediaIterator))) {
		NSEnumerator			*enumerator		= [_media objectEnumerator];
		CompactDiscController	*object			= nil;
		NSString				*bsdName		= getBSDName(nextMedia);

		while((object = [enumerator nextObject])) {
			NSString *comp = [[[object valueForKey:@"disc"] valueForKey:@"drive"] valueForKey:@"bsdName"];
			if([bsdName isEqualToString:comp]) {
				[object discUnmounted];
				[_media removeObject:object];
				break;
			}
		}
	}
	
	kernResult = IOObjectRelease(mediaIterator);
    if(KERN_SUCCESS != kernResult) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"IOObjectRelease returned %d", kernResult] userInfo:nil];
    }	
}

@end
