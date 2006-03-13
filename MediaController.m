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

#import "MediaController.h"

#import "CompactDisc.h"
#import "CompactDiscDocument.h"
#import "RipperController.h"
#import "EncoderController.h"
#import "IOException.h"
#import "MissingResourceException.h"

#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <DiskArbitration/DADisk.h>

@interface MediaController (Private)
- (void) volumeMounted:(NSString *)bsdName;
- (void) volumeUnmounted:(NSString *)bsdName;
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
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to unmount the disc", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:code], [NSString stringWithUTF8String:strerror(code)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		else {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to unmount the disc", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:status] forKey:@"errorCode"]];
		}
	}
}

static void ejectCallback(DADiskRef disk, DADissenterRef dissenter, void * context)
{
	if(NULL != dissenter) {
		DAReturn status = DADissenterGetStatus(dissenter);
		if(unix_err(status)) {
			int code = err_get_code(status);
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to eject the disc", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:code], [NSString stringWithUTF8String:strerror(code)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		else {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to eject the disc", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:status] forKey:@"errorCode"]];
		}
	}
}

static MediaController *sharedController = nil;

@implementation MediaController

+ (void) initialize
{
	NSString				*defaultsValuesPath;
    NSDictionary			*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"MediaControllerDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"MediaControllerDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

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

- (void) volumeMounted:(NSString *)bsdName
{
	CompactDisc				*disc		= [[[CompactDisc alloc] initWithBSDName:bsdName] autorelease];
	NSString				*filename	= [NSString stringWithFormat:@"%@/0x%.08x.cdinfo", getApplicationDataDirectory(), [disc discID]];
	NSURL					*url		= [NSURL fileURLWithPath:filename];
	CompactDiscDocument		*doc		= nil;
	NSError					*err		= nil;
	BOOL					newDisc		= NO;
	NSArray					*tracks		= nil;
	NSIndexSet				*indexSet	= nil;
	
	
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
		
		// Automatically query FreeDB for new discs if desired
		if(newDisc) {
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyQueryFreeDB"]) {
				[doc addObserver:self forKeyPath:@"freeDBQueryInProgress" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:doc];
				[doc queryFreeDB:self];
			}
		}
		
		// Automatic rip/encode functionality
		else if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyEncodeTracks"] && (NO == [[NSUserDefaults standardUserDefaults] boolForKey:@"onFirstInsertOnly"] || newDisc)) {
			[doc selectAll:self];
			//[[doc objectInTracksAtIndex:0] setSelected:YES];
			[doc encode:self];
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"ejectAfterRipping"]) {
				tracks		= [doc valueForKey:@"tracks"];
				indexSet	= [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tracks count])];
				
				[tracks addObserver:self toObjectsAtIndexes:indexSet forKeyPath:@"ripInProgress" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:doc];
				
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"closeWindowAfterEncoding"]) {					
					[tracks addObserver:self toObjectsAtIndexes:indexSet forKeyPath:@"encodeInProgress" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:doc];
				}
			}
		}
	}
	else {
		[[NSDocumentController sharedDocumentController] presentError:err];
	}
}

- (void) volumeUnmounted:(NSString *)bsdName
{
	NSArray					*documents				= [[NSDocumentController sharedDocumentController] documents];
	NSEnumerator			*documentEnumerator		= [documents objectEnumerator];
	CompactDiscDocument		*document;
	CompactDisc				*disc;
	
	while((document = [documentEnumerator nextObject])) {
		disc = [document disc];
		// If disc is nil, disc was unmounted by another agency (most likely user pressed eject key)
		if(nil != disc && [[disc bsdName] isEqualToString:bsdName]) {
			[document discEjected];
		}
	}
}

- (void) ejectDiscForCompactDiscDocument:(CompactDiscDocument *)document
{
	NSString	*bsdName	= [[document disc] bsdName];
	DADiskRef	disk		= DADiskCreateFromBSDName(kCFAllocatorDefault, _session, [bsdName fileSystemRepresentation]);
	
	// Close all open connections to the drive
	[document discEjected];
	
	DADiskUnmount(disk, kDADiskUnmountOptionDefault, unmountCallback, NULL);
	DADiskEject(disk, kDADiskEjectOptionDefault, ejectCallback, NULL);
	
	CFRelease(disk);
}

// This elaborate scheme is necessary since multiple threads are going at the same time
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	CompactDiscDocument		*doc		= (CompactDiscDocument *)context;
	NSArray					*tracks		= nil;
	NSIndexSet				*indexSet	= nil;
	
	if([keyPath isEqualToString:@"freeDBQueryInProgress"] && (NO == [[change objectForKey:NSKeyValueChangeNewKey] boolValue])) {

		[doc removeObserver:self forKeyPath:@"freeDBQueryInProgress"];

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallySaveFreeDBInfo"]) {
			[doc saveDocument:self];
		}
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyEncodeTracks"] && [doc freeDBQuerySuccessful]) {
			[doc selectAll:self];
			//[[doc objectInTracksAtIndex:0] setSelected:YES];
			[doc encode:self];
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"ejectAfterRipping"]) {
				tracks		= [doc valueForKey:@"tracks"];
				indexSet	= [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tracks count])];
				
				[tracks addObserver:self toObjectsAtIndexes:indexSet forKeyPath:@"ripInProgress" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:doc];
				
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"closeWindowAfterEncoding"]) {					
					[tracks addObserver:self toObjectsAtIndexes:indexSet forKeyPath:@"encodeInProgress" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:doc];
				}
			}
		}
	}
	else if([keyPath isEqualToString:@"ripInProgress"] && (NO == [[change objectForKey:NSKeyValueChangeNewKey] boolValue])) {
		if(NO == [[RipperController sharedController] documentHasRippingTasks:doc]) {
			tracks		= [doc valueForKey:@"tracks"];
			indexSet	= [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tracks count])];
			
			[tracks removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:@"ripInProgress"];
			
			[doc ejectDisc:self];
		}
	}
	else if([keyPath isEqualToString:@"encodeInProgress"] && (NO == [[change objectForKey:NSKeyValueChangeNewKey] boolValue])) {
		if(NO == [[RipperController sharedController] documentHasRipperTasks:doc] && NO == [[EncoderController sharedController] documentHasEncoderTasks:doc]) {
			tracks		= [doc valueForKey:@"tracks"];
			indexSet	= [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tracks count])];
			
			[tracks removeObserver:self fromObjectsAtIndexes:indexSet forKeyPath:@"encodeInProgress"];
			
			[doc saveDocument:self];
			[[doc windowForSheet] performClose:self];
		}
	}
}
	
@end
