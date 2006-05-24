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

#import "RipperController.h"
#import "BasicRipperTask.h"
#import "ComparisonRipperTask.h"
#import "ParanoiaRipperTask.h"
#import "LogController.h"
#import "EncoderController.h"
#import "ApplicationController.h"
#import "CompactDiscDocument.h"
#import "IOException.h"
#import "UtilityFunctions.h"

#import <Growl/GrowlApplicationBridge.h>

#include <paths.h>			// _PATH_TMP
#include <sys/param.h>		// statfs
#include <sys/mount.h>

static RipperController *sharedController = nil;

@interface RipperController (Private)
- (void)	updateFreeSpace:(NSTimer *)theTimer;
- (void)	addTask:(RipperTask *)task;
- (void)	removeTask:(RipperTask *)task;
- (void)	spawnThreads;
@end

@implementation RipperController

+ (RipperController *) sharedController
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
	if((self = [super initWithWindowNibName:@"Ripper"])) {
		
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
	[self setWindowFrameAutosaveName:@"Ripper"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

- (void) updateFreeSpace:(NSTimer *)theTimer
{
	const char				*tmpDir;
	struct statfs			buf;
	unsigned long long		bytesFree;
	long double				freeSpace;
	unsigned				divisions;
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
		tmpDir = [[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] fileSystemRepresentation];
	}
	else {
		tmpDir = _PATH_TMP;
	}
	
	if(-1 == statfs(tmpDir, &buf)) {
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

- (void)		ripTrack:(Track *)track					{ [self ripTracks:[NSArray arrayWithObject:track] metadata:[track metadata]]; }

- (void) ripTracks:(NSArray *)tracks metadata:(AudioMetadata *)metadata
{
	RipperTask	*task				= nil;
	int			selectedRipper		= kComparisonRipper;
		
	// Setup the ripper
	selectedRipper = [[NSUserDefaults standardUserDefaults] integerForKey:@"selectedRipper"];
	switch(selectedRipper) {
		case kBasicRipper:		task = [[BasicRipperTask alloc] initWithTracks:tracks metadata:metadata];		break;
		case kComparisonRipper:	task = [[ComparisonRipperTask alloc] initWithTracks:tracks metadata:metadata];	break;
		case kParanoiaRipper:	task = [[ParanoiaRipperTask alloc] initWithTracks:tracks metadata:metadata];	break;
		default:				task = [[ComparisonRipperTask alloc] initWithTracks:tracks metadata:metadata];	break;
	}
	
	// Set the active encoders in the task's userInfo dictionary
	[task setUserInfo:[NSDictionary dictionaryWithObject:[[[tracks objectAtIndex:0] document] activeEncoders] forKey:@"activeEncoders"]];
	
	// Show the window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] orderFront:self];
	}
	
	// Add the ripper to our list of ripping tasks
	[self addTask:[task autorelease]];
	[self spawnThreads];
}

- (BOOL) documentHasRipperTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator;
	RipperTask		*current;
	
	enumerator = [[_tasksController arrangedObjects] objectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[current objectInTracksAtIndex:0] document]]) {
			return YES;
		}
	}
	
	return NO;
}

- (void) stopRipperTasksForDocument:(CompactDiscDocument *)document
{
	NSEnumerator		*enumerator;
	RipperTask			*current;
	
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
	RipperTask			*current;
	
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
	RipperTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		[current stop];
	}
	_freeze = NO;
}

#pragma mark Callbacks

- (void) ripperTaskDidStart:(RipperTask *)task
{
	NSString *trackName = [task description];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip started for %@", @"Log", @""), trackName]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Rip started", @"Log", @"") description:trackName
						   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripperTaskDidStop:(RipperTask *)task
{
	NSString *trackName = [task description];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip stopped for %@", @"Log", @""), trackName]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Rip stopped", @"Log", @"") description:trackName
						   notificationName:@"Rip stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
}

- (void) ripperTaskDidComplete:(RipperTask *)task
{
	NSDate			*startTime		= [task startTime];
	NSDate			*endTime		= [task endTime];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*trackName		= [task description];
	BOOL			justNotified	= NO;
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip completed for %@", @"Log", @""), trackName]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Rip completed", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]]
						   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
		
	[self removeTask:task];
	[self spawnThreads];

	if(NO == [[[task objectInTracksAtIndex:0] document] ripInProgress]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Disc ripping completed", @"Log", @"")
									description:[NSString stringWithFormat:NSLocalizedStringFromTable(@"All ripping tasks completed for %@", @"Log", @""), [[task metadata] albumTitle]]
							   notificationName:@"Disc ripping completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
		justNotified = YES;
	}
	
	if(NO == [self hasTasks] && NO == justNotified) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Ripping completed", @"Log", @"")
									description:NSLocalizedStringFromTable(@"All ripping tasks completed", @"Log", @"")
							   notificationName:@"Ripping completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"ejectAfterRipping"] && NO == [[[task objectInTracksAtIndex:0] document] ripInProgress]) {
		[[[task objectInTracksAtIndex:0] document] ejectDisc:self];
	}

	[[EncoderController sharedController] runEncodersForTask:task];
}

#pragma mark Task Management

- (unsigned)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }
- (void)		addTask:(RipperTask *)task				{ [_tasksController addObject:task]; }

- (void) removeTask:(RipperTask *)task
{
	[_tasksController removeObject:task];
	
	// Hide the window if no more tasks
	if(NO == [self hasTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] performClose:self];
	}
}

- (void) spawnThreads
{
	NSMutableArray	*activeDrives = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator	*enumerator;
	RipperTask		*task;
	NSString		*deviceName;
	
	if(0 == [_tasks count] || _freeze) {
		return;
	}
	
	// Iterate through all ripping tasks once and determine which devices are active
	enumerator = [_tasks objectEnumerator];
	while((task = [enumerator nextObject])) {
		deviceName = [task deviceName];
		if([task started] && NO == [activeDrives containsObject:deviceName]) {
			[activeDrives addObject:deviceName];
		}
	}
	
	// Iterate through a second time and spawn threads for non-active devices
	enumerator = [_tasks objectEnumerator];
	while((task = [enumerator nextObject])) {
		deviceName = [task deviceName];
		if(NO == [task started] && NO == [activeDrives containsObject:deviceName]) {
			[activeDrives addObject:deviceName];
			[task run];
		}
	}
}

@end
