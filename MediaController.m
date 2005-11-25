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

#import "CompactDisc.h"
#import "CompactDiscDocument.h"

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

static MediaController *sharedController = nil;

@implementation MediaController

+ (MediaController *) sharedController
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

- (id) init
{
	NSNotificationCenter	*notificationCenter;

	if((self = [super init])) {
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
	
	[super dealloc];
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void) scanForMedia
{
	[self volumeMounted:nil];
}

// We don't actually use the notification, it is just a convenient hook
- (void) volumeMounted: (NSNotification *) notification
{
	kern_return_t	kernResult;
	io_iterator_t	mediaIterator;
	io_object_t		nextMedia;
	
	kernResult = findEjectableCDMedia(&mediaIterator);
	
	while((nextMedia = IOIteratorNext(mediaIterator))) {

		NSString				*bsdName	= getBSDName(nextMedia);
		CompactDisc				*disc		= [[[CompactDisc alloc] initWithBSDName:bsdName] autorelease];

		NSString				*filename	= [NSString stringWithFormat:@"%@/0x%.08x.xml", getApplicationDataDirectory(), [disc discID]];
		NSURL					*url		= [NSURL fileURLWithPath:filename];
		CompactDiscDocument		*doc		= nil;
		NSError					*err		= nil;
		BOOL					queryFreeDB = NO;
		
		// If the file exists open it (disc already seen)
		if([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
			doc	= [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:NO error:&err];
		}
		else {
			// Ugly hack to avoid letting the user specify the save filename
			[[NSFileManager defaultManager] createFileAtPath:filename contents:nil attributes:nil];
			doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO error:&err];
			[doc setFileURL:url];
			queryFreeDB = YES;
		}
		
		if(nil != doc && nil == [doc getDisc]) {
			[doc setDisc:disc];
			if(0 == [[doc windowControllers] count]) {
				[doc makeWindowControllers];
				[doc showWindows];				
			}
			if(queryFreeDB) {
				[doc getCDInformation:self];
			}
		}
		else {
			[[NSDocumentController sharedDocumentController] presentError:err];
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
		NSString				*bsdName	= getBSDName(nextMedia);
		CompactDisc				*disc		= [[[CompactDisc alloc] initWithBSDName:bsdName] autorelease];
		
		NSString				*filename	= [NSString stringWithFormat:@"%@/0x%.08x.xml", getApplicationDataDirectory(), [disc discID]];
		NSURL					*url		= [NSURL fileURLWithPath:filename];
		CompactDiscDocument		*doc		= [[NSDocumentController sharedDocumentController] documentForURL:url];
		
		if(nil != doc) {
			[doc discEjected];
		}
	}
	
	kernResult = IOObjectRelease(mediaIterator);
    if(KERN_SUCCESS != kernResult) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"IOObjectRelease returned %d", kernResult] userInfo:nil];
    }	
}

@end
