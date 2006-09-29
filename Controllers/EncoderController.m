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

#import "SecondsFormatter.h"
#import "RipperTask.h"

#import "CoreAudioEncoderTask.h"
#import "FLACEncoderTask.h"
#import "MonkeysAudioEncoderTask.h"
#import "MPEGEncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggSpeexEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "LibsndfileEncoderTask.h"
#import "WavPackEncoderTask.h"

#import "LogController.h"
#import "RipperController.h"

#import "IOException.h"
#import "MissingResourceException.h"

#import <Growl/GrowlApplicationBridge.h>
#include <AudioToolbox/AudioFile.h>
#include <sndfile/sndfile.h>

#include <sys/param.h>		// statfs
#include <sys/mount.h>

static EncoderController *sharedController = nil;

@interface EncoderController (Private)
- (void)	runEncoder:(Class)encoderClass taskInfo:(TaskInfo *)taskInfo encoderSettings:(NSDictionary *)encoderSettings;
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
		
		_tasks		= [[NSMutableArray alloc] init];

		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_tasks release];		_tasks = nil;

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
	[self setWindowFrameAutosaveName:@"Encoder"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

#pragma mark Functionality

- (void) encodeFile:(NSString *)filename metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings
{
	[self encodeFiles:[NSArray arrayWithObject:filename] metadata:metadata settings:settings];
}

- (void) encodeFiles:(NSArray *)filenames metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings
{
	TaskInfo		*taskInfo			= [TaskInfo taskInfoWithSettings:settings metadata:metadata];
	NSArray			*outputFormats		= [settings objectForKey:@"encoders"];
	NSDictionary	*format				= nil;
	unsigned		i					= 0;
	
	[taskInfo setInputFilenames:filenames];
	
	for(i = 0; i < [outputFormats count]; ++i) {
		format = [outputFormats objectAtIndex:i];
		
		switch([[format objectForKey:@"component"] intValue]) {
			
			case kComponentFLAC:
				[self runEncoder:[FLACEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentOggFLAC:
				[self runEncoder:[OggFLACEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentWavPack:
				[self runEncoder:[WavPackEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentMonkeysAudio:
				[self runEncoder:[MonkeysAudioEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentOggVorbis:
				[self runEncoder:[OggVorbisEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentMPEG:
				[self runEncoder:[MPEGEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentOggSpeex:
				[self runEncoder:[OggSpeexEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentCoreAudio:
				[self runEncoder:[CoreAudioEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			case kComponentLibsndfile:
				[self runEncoder:[LibsndfileEncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
				break;
				
			default:
				NSLog(@"Unknown component: %@", [format objectForKey:@"component"]);
				break;
		}
		
	}	
}

- (BOOL) documentHasEncoderTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator;
	EncoderTask		*current;
	
	enumerator = [[_tasksController arrangedObjects] objectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[[[current taskInfo] inputTracks] objectAtIndex:0] document]]) {
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
		if([document isEqual:[[[[current taskInfo] inputTracks] objectAtIndex:0] document]]) {
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
	NSString	*type			= [task outputFormatName];
	NSString	*settings		= [task encoderSettingsString];
	
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
	NSString	*type			= [task outputFormatName];
	
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
	NSString		*type			= [task outputFormatName];
	BOOL			justNotified	= NO;
		
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode completed for %@ [%@]", @"Log", @""), trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode completed", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type], [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]]
						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
	
	if(0 != [[[task taskInfo] inputTracks] count] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] ripInProgress] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] encodeInProgress]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Disc encoding completed", @"Log", @"")
									description:[NSString stringWithFormat:NSLocalizedStringFromTable(@"All encoding tasks completed for %@", @"Log", @""), [[[task taskInfo] metadata] albumTitle]]
							   notificationName:@"Disc encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
		justNotified = YES;
	}

	// No more tasks in any queues
	if(NO == [self hasTasks] && NO == [[RipperController sharedController] hasTasks]) {

		// Bounce dock icon if we're not the active application
		if(NO == [[NSApplication sharedApplication] isActive]) {
			[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];			
		}
		
		// Try to avoid Growl floods
		if(NO == justNotified) {
			[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encoding completed", @"Log", @"")
										description:NSLocalizedStringFromTable(@"All encoding tasks completed", @"Log", @"")
								   notificationName:@"Encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
		}
	}

	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"closeWindowAfterEncoding"] && 0 != [[[task taskInfo] inputTracks] count] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] ripInProgress] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] encodeInProgress]) {
		CompactDiscDocument		*doc	= [[[[task taskInfo] inputTracks] objectAtIndex:0] document];
		[doc saveDocument:self];
		[[doc windowForSheet] performClose:self];
	}
}

#pragma mark Task Management

- (unsigned)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }

@end

@implementation EncoderController (Private)

- (void) runEncoder:(Class)encoderClass taskInfo:(TaskInfo *)taskInfo encoderSettings:(NSDictionary *)encoderSettings
{
	EncoderTask				*encoderTask			= nil;
	
	// Create the task
	encoderTask		= [[encoderClass alloc] init];
	
	// Set the task info
	[encoderTask setTaskInfo:taskInfo];
	
	// Pass the encoding configuration parameters
	[encoderTask setEncoderSettings:encoderSettings];
	
	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] orderFront:self];
	}
	
	// Add the encoder to our list of encoding tasks
	[self addTask:[encoderTask autorelease]];
	[self spawnThreads];
}

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
}

@end
