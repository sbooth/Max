/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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
#import "LogController.h"
#import "UtilityFunctions.h"

#include <CoreFoundation/CoreFoundation.h>
#include <DiskArbitration/DiskArbitration.h>
#include <DiskArbitration/DADisk.h>

@interface MediaController (Private)
- (void) volumeMounted:(NSString *)deviceName;
- (void) volumeUnmounted:(NSString *)deviceName;
@end

#pragma mark DiskArbitration callback functions

static void diskAppearedCallback(DADiskRef disk, void * context);
static void diskDisappearedCallback(DADiskRef disk, void * context);
static void unmountCallback(DADiskRef disk, DADissenterRef dissenter, void * context);
static void ejectCallback(DADiskRef disk, DADissenterRef dissenter, void * context);

static void diskAppearedCallback(DADiskRef disk, void * context)
{
	[[MediaController sharedController] volumeMounted:[NSString stringWithCString:DADiskGetBSDName(disk) encoding:NSASCIIStringEncoding]];
}

static void diskDisappearedCallback(DADiskRef disk, void * context)
{
	[[MediaController sharedController] volumeUnmounted:[NSString stringWithCString:DADiskGetBSDName(disk) encoding:NSASCIIStringEncoding]];
}

static void unmountCallback(DADiskRef disk, DADissenterRef dissenter, void * context)
{
	@try {
		if(NULL != dissenter) {
			DAReturn status = DADissenterGetStatus(dissenter);
			if(unix_err(status)) {
				int code = err_get_code(status);
				@throw [NSException exceptionWithName:@"IOException"
											   reason:NSLocalizedStringFromTable(@"Unable to unmount the disc.", @"Exceptions", @"") 
											 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:code], [NSString stringWithCString:strerror(code) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			else {
				@throw [NSException exceptionWithName:@"IOException"
											   reason:NSLocalizedStringFromTable(@"Unable to unmount the disc.", @"Exceptions", @"") 
											 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:status] forKey:@"errorCode"]];
			}
		}
		
		// Only try to eject the disc if it was already successfully unmounted
		DADiskEject(disk, kDADiskEjectOptionDefault, ejectCallback, context);
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred on device %s.", @"Exceptions", @""), DADiskGetBSDName(disk)]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

static void ejectCallback(DADiskRef disk, DADissenterRef dissenter, void * context)
{
	CompactDiscDocument		*document	= (CompactDiscDocument *)context;

	@try {
		if(NULL != dissenter) {
			DAReturn status = DADissenterGetStatus(dissenter);
			if(unix_err(status)) {
				int code = err_get_code(status);
				@throw [NSException exceptionWithName:@"IOException"
											   reason:NSLocalizedStringFromTable(@"Unable to eject the disc.", @"Exceptions", @"") 
											 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:code], [NSString stringWithCString:strerror(code) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			else {
				@throw [NSException exceptionWithName:@"IOException"
											   reason:NSLocalizedStringFromTable(@"Unable to eject the disc.", @"Exceptions", @"") 
											 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:status] forKey:@"errorCode"]];
			}
		}
		
		// Let the document know the disc has been ejected
		[document discEjected];
	}

	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred on device %s.", @"Exceptions", @""), DADiskGetBSDName(disk)]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
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
		NSAssert1(nil != defaultsValuesPath, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"MediaControllerDefaults.plist");

		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"MediaController"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

+ (MediaController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController)
			[[self alloc] init];
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            sharedController = [super allocWithZone:zone];
			return sharedController;
        }
    }
    return nil;
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
		
		return self;
	}
	return nil;
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
- (NSUInteger) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void) release											{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void) volumeMounted:(NSString *)deviceName
{
	CompactDisc				*disc			= nil;
	NSString				*filename		= nil;
	NSString				*oldFilename	= nil;
	NSURL					*url			= nil;
	CompactDiscDocument		*doc			= nil;
	NSError					*err			= nil;
	BOOL					newDisc			= NO;
	
	@try {
		
		[LogController logMessage:[NSString stringWithFormat:@"Found CD on device %@", deviceName]];
		
		disc		= [[[CompactDisc alloc] initWithDeviceName:deviceName] autorelease];
		filename	= [NSString stringWithFormat:@"%@/%@.cdinfo", GetApplicationDataDirectory(), [disc discID]];
		oldFilename	= [NSString stringWithFormat:@"%@/0x%@.cdinfo", GetApplicationDataDirectory(), [disc freeDBDiscID]];
		url			= [NSURL fileURLWithPath:filename];

		// If a .cdinfo file exists with the old FreeDB ID naming scheme, rename it
		if([[NSFileManager defaultManager] fileExistsAtPath:oldFilename] && NO == [[NSFileManager defaultManager] fileExistsAtPath:filename])
			/* BOOL result = */[[NSFileManager defaultManager] moveItemAtPath:oldFilename toPath:filename error:nil];
		
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
			
			// Automatically query MusicBrainz for new discs if desired
			if(newDisc) {
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyQueryMusicBrainz"])
					[doc queryMusicBrainzNonInteractive];

				if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallySaveMusicBrainzInfo"])
					[doc saveDocument:self];
			}
			
			// Automatic rip/encode functionality
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyEncodeTracks"] && (NO == [[NSUserDefaults standardUserDefaults] boolForKey:@"onFirstInsertOnly"] || newDisc)) {
				[doc selectAll:self];
				//[[doc objectInTracksAtIndex:0] setSelected:YES];
				[doc encode:self];
			}
		}
		else
			[[NSDocumentController sharedDocumentController] presentError:err];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while accessing the disc on device %@.", @"Exceptions", @""), deviceName]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (void) volumeUnmounted:(NSString *)deviceName
{
	NSEnumerator			*documentEnumerator		= [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
	CompactDiscDocument		*document;
	CompactDisc				*disc;
	
	while((document = [documentEnumerator nextObject])) {
		disc = [document disc];
		// If disc is nil, disc was unmounted by another agency (most likely user pressed eject key)
		if(nil != disc && [[disc deviceName] isEqualToString:deviceName])
			[document discEjected];
	}
}

- (void) ejectDiscForDocument:(CompactDiscDocument *)document
{
	NSString	*deviceName	= [[document disc] deviceName];
	DADiskRef	disk		= DADiskCreateFromBSDName(kCFAllocatorDefault, _session, [deviceName fileSystemRepresentation]);

	// If the disc is successfully unmounted, unmountCallback will eject it
	DADiskUnmount(disk, kDADiskUnmountOptionWhole, unmountCallback, document);
	
	CFRelease(disk);
}
	
@end
