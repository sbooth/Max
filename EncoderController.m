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
#import "RipperTask.h"
#import "PCMGeneratingTask.h"
#import "MPEGEncoderTask.h"
#import "FLACEncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "CoreAudioEncoderTask.h"
#import "LibsndfileEncoderTask.h"
#import "MonkeysAudioEncoderTask.h"
#import "SpeexEncoderTask.h"
#import "LogController.h"
#import "ConverterController.h"
#import "IOException.h"

#import <Growl/GrowlApplicationBridge.h>

#include <sys/param.h>		// statfs
#include <sys/mount.h>

static EncoderController *sharedController = nil;

@interface EncoderController (Private)
- (void)	updateFreeSpace:(NSTimer *)theTimer;
- (void)	runEncoder:(Class)encoderClass forTask:(PCMGeneratingTask *)task;
- (void)	addTask:(EncoderTask *)task;
- (void)	removeTask:(EncoderTask *)task;
- (void)	spawnThreads;
@end

@implementation EncoderController

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

- (id) init
{
	if((self = [super initWithWindowNibName:@"Encoder"])) {
		
		_timer		= [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateFreeSpace:) userInfo:nil repeats:YES];
		_tasks		= [[NSMutableArray arrayWithCapacity:50] retain];
		_freeze		= NO;

		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_timer invalidate];
	[_tasks release];

	[super dealloc];
}

- (void) awakeFromNib
{
	[_taskTable setAutosaveTableColumns:YES];
}

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
	
	if(-1 == statfs([[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] fileSystemRepresentation], &buf)) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get file system statistics.", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
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

#pragma mark Functionality

- (void) runEncodersForTask:(PCMGeneratingTask *)task
{
	NSArray			*libsndfileFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"libsndfileOutputFormats"];
	NSArray			*coreAudioFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"coreAudioOutputFormats"];
	
	// Create encoder tasks for the rip/convert that just completed
	@try {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputMP3"]) {
			[self runEncoder:[MPEGEncoderTask class] forTask:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputFLAC"]) {
			[self runEncoder:[FLACEncoderTask class] forTask:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggFLAC"]) {
			[self runEncoder:[OggFLACEncoderTask class] forTask:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggVorbis"]) {
			[self runEncoder:[OggVorbisEncoderTask class] forTask:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputMonkeysAudio"]) {
			[self runEncoder:[MonkeysAudioEncoderTask class] forTask:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputSpeex"]) {
			[self runEncoder:[SpeexEncoderTask class] forTask:task];
		}
		
		// Core Audio encoders
		if(nil != coreAudioFormats && 0 < [coreAudioFormats count]) {
			EncoderTask		*encoderTask;
			NSEnumerator	*formats		= [coreAudioFormats objectEnumerator];
			NSDictionary	*formatInfo;
			
			while((formatInfo = [formats nextObject])) {
				
				encoderTask = [[CoreAudioEncoderTask alloc] initWithTask:task formatInfo:formatInfo];
				
				if([task isKindOfClass:[RipperTask class]]) {
					[encoderTask setTracks:[(RipperTask *)task valueForKey:@"tracks"]];
				}
				
				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
					[[self window] orderFront:self];
				}
				
				// Add the encoder to our list of encoding tasks
				[self addTask:[encoderTask autorelease]];
				[self spawnThreads];
			}
		}
		
		// libsndfile encoders
		if(nil != libsndfileFormats && 0 < [libsndfileFormats count]) {
			NSEnumerator	*formats		= [libsndfileFormats objectEnumerator];
			NSDictionary	*formatInfo;
			
			while((formatInfo = [formats nextObject])) {
				
				EncoderTask *encoderTask = [[LibsndfileEncoderTask alloc] initWithTask:task formatInfo:formatInfo];
				
				if([task isKindOfClass:[RipperTask class]]) {
					[encoderTask setTracks:[(RipperTask *)task valueForKey:@"tracks"]];
				}
				
				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
					[[self window] orderFront:self];
				}
				
				// Add the encoder to our list of encoding tasks
				[self addTask:[encoderTask autorelease]];
				[self spawnThreads];
			}
		}
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while encoding the file \"%@\".", @"Exceptions", @""), [[task outputFilename] lastPathComponent]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (void) runEncoder:(Class)encoderClass forTask:(PCMGeneratingTask *)task
{
	// Create the encoder (relies on each subclass having the same method signature)
	EncoderTask *encoderTask = [[encoderClass alloc] initWithTask:task];
	
	if([task isKindOfClass:[RipperTask class]]) {
		[encoderTask setTracks:[(RipperTask *)task valueForKey:@"tracks"]];
	}
	
	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] orderFront:self];
	}
	
	// Add the encoder to our list of encoding tasks
	[self addTask:[encoderTask autorelease]];
	[self spawnThreads];
}

- (BOOL) documentHasEncoderTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator;
	EncoderTask		*current;
	
	enumerator = [[_tasksController arrangedObjects] objectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[current objectInTracksAtIndex:0] document]]) {
			return YES;
		}
	}
	
	return NO;
}

- (void) stopEncoderTasksForDocument:(CompactDiscDocument *)document
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[current objectInTracksAtIndex:0] document]]) {
			[current stop];
		}
	}
	_freeze = NO;
}

#pragma Action Methods

- (IBAction) stopSelectedTasks:(id)sender
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController selectedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		[current stop];
	}
	_freeze = NO;
}

- (IBAction) stopAllTasks:(id)sender
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		[current stop];
	}
	_freeze = NO;
}

#pragma mark Callbacks

- (void) encoderTaskDidStart:(EncoderTask *)task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task outputFormat];
	NSString	*settings		= [task settings];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode started for %@ [%@]", @"Log", @""), trackName, type]];
	if(nil != settings) {
		[LogController logMessage:settings];
	}
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode started", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encoderTaskDidStop:(EncoderTask *)task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task outputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode stopped for %@ [%@]", @"Log", @""), trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode stopped", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
}

- (void) encoderTaskDidComplete:(EncoderTask *)task
{
	NSDate			*startTime		= [task startTime];
	NSDate			*endTime		= [task endTime];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*trackName		= [task description];
	NSString		*type			= [task outputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode completed for %@ [%@]", @"Log", @""), trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode completed", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type], [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]]
						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
	
	if(NO == [self hasTasks]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encoding completed", @"Log", @"")
									description:NSLocalizedStringFromTable(@"All encoding tasks completed", @"Log", @"")
							   notificationName:@"Encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}

	if(0 != [task countOfTracks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"closeWindowAfterEncoding"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"ejectAfterRipping"] && NO == [self documentHasEncoderTasks:[[task objectInTracksAtIndex:0] document]]) {
		CompactDiscDocument *doc = [[task objectInTracksAtIndex:0] document];
		[doc saveDocument:self];
		[[doc windowForSheet] performClose:self];
	}	
}

#pragma mark Task Management

- (unsigned)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }
- (void)		addTask:(EncoderTask *)task				{ [_tasksController addObject:task]; }

- (void) removeTask:(EncoderTask *)task
{
	[_tasksController removeObject:task];
	
	// Hide the window if no more tasks
	if(NO == [self hasTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] performClose:self];
	}
}

- (void) spawnThreads
{
	unsigned	maxThreads		= (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];
	unsigned	i;
	unsigned	limit;
	
	if(0 == [_tasks count] || _freeze) {
		return;
	}
	
	limit = (maxThreads < [_tasks count] ? maxThreads : [_tasks count]);
	
	// Start encoding the next track(s)
	for(i = 0; i < limit; ++i) {
		if(NO == [[_tasks objectAtIndex:i] started]) {
			[[_tasks objectAtIndex:i] run];
		}	
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"balanceConverters"]) {
		[[ConverterController sharedController] spawnThreads];
	}
}

@end
