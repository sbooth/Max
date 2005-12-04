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
#include <DiskArbitration/DiskArbitration.h>
#include <DiskArbitration/DADisk.h>

@interface MediaController (Private)
- (void) volumeMounted: (NSString *)bsdName;
- (void) volumeUnmounted: (NSString *)bsdName;
@end

#pragma mark DiskArbitration callback functions

static void diskAppearedCallback(DADiskRef disk, void * context)
{
	[[MediaController sharedController] volumeMounted:[NSString stringWithUTF8String:DADiskGetBSDName(disk)]];
}

static void diskDisappearedCallback(DADiskRef disk, void * context)
{
	[[MediaController sharedController] volumeUnmounted:[NSString stringWithUTF8String:DADiskGetBSDName(disk)]];
}

static void unmountCallback(DADiskRef disk, DADissenterRef dissenter, void * context)
{
	if(NULL != dissenter) {
		DAReturn status = DADissenterGetStatus(dissenter);
		if(unix_err(status)) {
			int code = err_get_code(status);
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to unmount disc (%i:%s)", code, strerror(code)] userInfo:nil];
		}
		else {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to unmount disc (0x%.8x)", status] userInfo:nil];
		}
	}
}

static void ejectCallback(DADiskRef disk, DADissenterRef dissenter, void * context)
{
	if(NULL != dissenter) {
		DAReturn status = DADissenterGetStatus(dissenter);
		if(unix_err(status)) {
			int code = err_get_code(status);
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to eject disc (%i:%s)", code, strerror(code)] userInfo:nil];
		}
		else {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to eject disc (0x%.8x)", status] userInfo:nil];
		}
	}
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
	if((self = [super init])) {
		// Only request mount/unmount information for audio CDs
		NSDictionary *match = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"IOCDMedia", [NSNumber numberWithBool:YES], nil] 
														  forKeys:[NSArray arrayWithObjects:(NSString *)kDADiskDescriptionMediaKindKey, kDADiskDescriptionMediaWholeKey, nil]];
		
		_session = DASessionCreate(kCFAllocatorDefault);
		DASessionScheduleWithRunLoop(_session, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		DARegisterDiskAppearedCallback(_session, (CFDictionaryRef)match, diskAppearedCallback, NULL);
		DARegisterDiskDisappearedCallback(_session, (CFDictionaryRef)match, diskDisappearedCallback, NULL);
	}
	return self;
}

- (void) dealloc
{
	DAUnregisterCallback(_session, diskAppearedCallback, NULL);
	DAUnregisterCallback(_session, diskDisappearedCallback, NULL);
	DASessionUnscheduleFromRunLoop(_session, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	CFRelease(_session);
		
	[super dealloc];
}

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void) volumeMounted: (NSString *) bsdName
{
	CompactDisc				*disc		= [[[CompactDisc alloc] initWithBSDName:bsdName] autorelease];
	NSString				*filename	= [NSString stringWithFormat:@"%@/0x%.08x.xml", getApplicationDataDirectory(), [disc discID]];
	NSURL					*url		= [NSURL fileURLWithPath:filename];
	CompactDiscDocument		*doc		= nil;
	NSError					*err		= nil;
	BOOL					newDisc		= NO;
	
	// Ugly hack to avoid letting the user specify the save filename
	if(NO == [[NSFileManager defaultManager] fileExistsAtPath:filename]) {
		[[NSFileManager defaultManager] createFileAtPath:filename contents:nil attributes:nil];
		newDisc = YES;
	}

	doc	= [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:NO error:&err];
	
	if(nil != doc) {
		[doc setDisc:disc];
		
		if(0 == [[doc windowControllers] count]) {
			[doc makeWindowControllers];
			[doc showWindows];		
		}
		
		if(newDisc) {
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyQueryFreeDB"]) {
				[doc queryFreeDB:self];
			}				
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyEncodeTracks"]) {
				[doc selectAll:self];
				[doc encode:self];
			}
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"ejectAfterRipping"]) {
				[[doc getDisc] eject];
			}
		}
	}
	else {
		[[NSDocumentController sharedDocumentController] presentError:err];
	}
}

- (void) volumeUnmounted: (NSString *) bsdName
{
	NSArray					*documents				= [[NSDocumentController sharedDocumentController] documents];
	NSEnumerator			*documentEnumerator		= [documents objectEnumerator];
	CompactDiscDocument		*document;
	CompactDisc				*disc;
	
	while((document = [documentEnumerator nextObject])) {
		disc = [document getDisc];
		// If disc is nil, disc was unmounted by another agency (most likely user pressed eject key)
		if(nil != disc && [[disc bsdName] isEqualToString:bsdName]) {
			[document discEjected];
		}
	}
}

- (void) ejectDiscForCompactDiscDocument:(CompactDiscDocument *)document
{
	NSString	*bsdName	= [[document getDisc] bsdName];
	DADiskRef	disk		= DADiskCreateFromBSDName(kCFAllocatorDefault, _session, [bsdName UTF8String]);
	
	// Close all open connections to the drive
	[document discEjected];
	
	DADiskUnmount(disk, kDADiskUnmountOptionDefault, unmountCallback, NULL);
	DADiskEject(disk, kDADiskEjectOptionDefault, ejectCallback, NULL);
	
	CFRelease(disk);
}

@end
