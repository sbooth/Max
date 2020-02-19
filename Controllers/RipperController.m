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

#import "RipperController.h"

#import "SecondsFormatter.h"
#import "BasicRipperTask.h"
#import "ComparisonRipperTask.h"
#import "ParanoiaRipperTask.h"
#import "LogController.h"
#import "EncoderController.h"
#import "ApplicationController.h"
#import "CompactDiscDocument.h"
#import "MediaController.h"
#import "UtilityFunctions.h"

#include <paths.h>			// _PATH_TMP
#include <sys/param.h>		// statfs
#include <sys/mount.h>

static RipperController *sharedController = nil;

@interface RipperController (Private)
- (void)	addTask:(RipperTask *)task;
- (void)	removeTask:(RipperTask *)task;
- (void)	spawnThreads;
@end

@implementation RipperController

+ (RipperController *) sharedController
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

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (NSUInteger)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void)	release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

- (id) init
{
	if((self = [super initWithWindowNibName:@"Ripper"])) {
		
		_tasks		= [[NSMutableArray alloc] init];
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_tasks release];
	_tasks = nil;

	[super dealloc];
}

- (void) awakeFromNib
{
	[_taskTable setAutosaveTableColumns:YES];
	[[[_taskTable tableColumnWithIdentifier:@"remaining"] dataCell] setFormatter:[[[SecondsFormatter alloc] init] autorelease]];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Ripper"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

#pragma mark Functionality

- (void) ripTracks:(NSArray *)tracks settings:(NSDictionary *)settings
{
	RipperTask				*ripperTask				= nil;
	TaskInfo				*taskInfo				= nil;	
	int						selectedRipper			= kComparisonRipper;
		
	NSParameterAssert(nil != tracks);
	NSParameterAssert(nil != settings);
	
	// Create the task
	selectedRipper	= [[settings objectForKey:@"selectedRipper"] intValue];
	
	// Create one RipperTask for all the tracks
	if([[settings objectForKey:@"ripToSingleFile"] boolValue] && 1 < [tracks count]) {
		AudioMetadata			*metadata				= nil;
		
		metadata = [(Track *)[tracks objectAtIndex:0] metadata];
		
		// Adjust metadata to reflect only album tags
		[metadata setTrackNumber:0];
		[metadata setTrackTitle:NSLocalizedStringFromTable(@"Multiple Tracks", @"CompactDisc", @"")];
		[metadata setTrackArtist:nil];
		[metadata setTrackGenre:nil];
		[metadata setTrackComposer:nil];
		[metadata setTrackDate:nil];
		[metadata setISRC:nil];

		switch(selectedRipper) {
			case kBasicRipper:		ripperTask = [[BasicRipperTask alloc] initWithTracks:tracks];		break;
			case kComparisonRipper:	ripperTask = [[ComparisonRipperTask alloc] initWithTracks:tracks];	break;
			case kParanoiaRipper:	ripperTask = [[ParanoiaRipperTask alloc] initWithTracks:tracks];	break;
			default:				ripperTask = [[ComparisonRipperTask alloc] initWithTracks:tracks];	break;
		}
		
		// Create the task info
		taskInfo		= [TaskInfo taskInfoWithSettings:settings metadata:metadata];
		[taskInfo setInputTracks:tracks];
		[ripperTask setTaskInfo:taskInfo];
		
		// Show the window if it is hidden
		if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
			[[self window] orderFront:self];
		}
		
		// Add the ripper to our list of ripping tasks
		[self addTask:[ripperTask autorelease]];
		[self spawnThreads];
	}
	// Create one RipperTask per track
	else {
		Track			*track;

		for(track in tracks) {
			switch(selectedRipper) {
				case kBasicRipper:		ripperTask = [[BasicRipperTask alloc] initWithTracks:[NSArray arrayWithObject:track]];		break;
				case kComparisonRipper:	ripperTask = [[ComparisonRipperTask alloc] initWithTracks:[NSArray arrayWithObject:track]];	break;
				case kParanoiaRipper:	ripperTask = [[ParanoiaRipperTask alloc] initWithTracks:[NSArray arrayWithObject:track]];	break;
				default:				ripperTask = [[ComparisonRipperTask alloc] initWithTracks:[NSArray arrayWithObject:track]];	break;
			}
			
			// Create the task info
			taskInfo		= [TaskInfo taskInfoWithSettings:settings metadata:[track metadata]];
			[taskInfo setInputTracks:[NSArray arrayWithObject:track]];
			[ripperTask setTaskInfo:taskInfo];

			// Show the window if it is hidden
			if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
				[[self window] orderFront:self];
			}
			
			// Add the ripper to our list of ripping tasks
			[self addTask:[ripperTask autorelease]];
			[self spawnThreads];
		}
	}
}

- (BOOL) documentHasRipperTasks:(CompactDiscDocument *)document
{
	RipperTask		*current;
	
	for(current in _tasks) {
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
	enumerator = [_tasks reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[current objectInTracksAtIndex:0] document]]) {
			[current stop];
		}
	}
	_freeze = NO;
}

#pragma mark Action Methods

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
	NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
	notification.title = NSLocalizedStringFromTable(@"Rip started", @"Log", @"");
	notification.informativeText = trackName;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void) ripperTaskDidStop:(RipperTask *)task
{
	NSString *trackName = [task description];
		
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip stopped for %@", @"Log", @""), trackName]];
	NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
	notification.title = NSLocalizedStringFromTable(@"Rip stopped", @"Log", @"");
	notification.informativeText = trackName;
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

	[task retain];

	[self removeTask:task];
	[self spawnThreads];

	// Eject the disc, if necessary
	if([[[task objectInTracksAtIndex:0] document] ejectRequested] && NO == [self documentHasRipperTasks:[[task objectInTracksAtIndex:0] document]]) {
		[[MediaController sharedController] ejectDiscForDocument:[[task objectInTracksAtIndex:0] document]];
		[[[task objectInTracksAtIndex:0] document] setEjectRequested:NO];
	}
	
	[task release];
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
	NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
	notification.title = NSLocalizedStringFromTable(@"Rip completed", @"Log", @"");
	notification.informativeText = [NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]];
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

	[task retain];

	[self removeTask:task];
	[self spawnThreads];

	if(NO == [[[task objectInTracksAtIndex:0] document] ripInProgress]) {
		NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
		notification.title = NSLocalizedStringFromTable(@"Disc ripping completed", @"Log", @"");
		notification.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"All ripping tasks completed for %@", @"Log", @""), [[[task taskInfo] metadata] albumTitle]];
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
		justNotified = YES;
	}
	
	if(NO == [self hasTasks] && NO == justNotified) {
		NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
		notification.title = NSLocalizedStringFromTable(@"Ripping completed", @"Log", @"");
		notification.informativeText = NSLocalizedStringFromTable(@"All ripping tasks completed", @"Log", @"");
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"ejectAfterRipping"] && NO == [self documentHasRipperTasks:[[task objectInTracksAtIndex:0] document]]) {
		[[[task objectInTracksAtIndex:0] document] ejectDisc:self];
	}

	[[EncoderController sharedController] encodeFile:[task outputFilename] metadata:[[task taskInfo] metadata] settings:[[task taskInfo] settings] inputTracks:[[task taskInfo] inputTracks]];
	
	[task release];
}

#pragma mark Task Management

- (NSUInteger)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }

@end

@implementation RipperController (Private)

- (void)		addTask:(RipperTask *)task				{ [[self mutableArrayValueForKey:@"tasks"] addObject:task]; }

- (void) removeTask:(RipperTask *)task
{
	[[self mutableArrayValueForKey:@"tasks"] removeObject:task];
	
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
	for(task in _tasks) {
		deviceName = [task deviceName];
		if(NO == [task started] && NO == [activeDrives containsObject:deviceName]) {
			[activeDrives addObject:deviceName];
			[task run];
		}
	}
}

@end
