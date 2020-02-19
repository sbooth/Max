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

#import "EncoderController.h"

#import "SecondsFormatter.h"
#import "RipperTask.h"

#import "CoreAudioEncoderTask.h"
#import "FLACEncoderTask.h"
#import "MonkeysAudioEncoderTask.h"
#import "MP3EncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggSpeexEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "LibsndfileEncoderTask.h"
#import "WavPackEncoderTask.h"

#import "LogController.h"
#import "RipperController.h"

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
	if((self = [super initWithWindowNibName:@"Encoder"])) {		
		_tasks = [[NSMutableArray alloc] init];
	}
	
	return self;
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
	[self setWindowFrameAutosaveName:@"Encoder"];
	[[self window] setExcludedFromWindowsMenu:YES];
}

#pragma mark Functionality

- (void) encodeFile:(NSString *)filename metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings
{
	[self encodeFiles:[NSArray arrayWithObject:filename] metadata:metadata settings:settings inputTracks:nil];
}

- (void) encodeFile:(NSString *)filename metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings inputTracks:(NSArray *)inputTracks
{
	[self encodeFiles:[NSArray arrayWithObject:filename] metadata:metadata settings:settings inputTracks:inputTracks];
}

- (void) encodeFiles:(NSArray *)filenames metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings
{
	[self encodeFiles:filenames metadata:metadata settings:settings inputTracks:nil];
}

- (void) encodeFiles:(NSArray *)filenames metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings inputTracks:(NSArray *)inputTracks
{
	TaskInfo		*taskInfo			= [TaskInfo taskInfoWithSettings:settings metadata:metadata];
	NSArray			*outputFormats		= [settings objectForKey:@"encoders"];
	NSDictionary	*format				= nil;
	NSUInteger		i					= 0;
	
	[taskInfo setInputFilenames:filenames];
	[taskInfo setInputTracks:inputTracks];
	
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
				
			case kComponentMP3:
				[self runEncoder:[MP3EncoderTask class] taskInfo:taskInfo encoderSettings:[format objectForKey:@"settings"]];
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
	EncoderTask		*current;
	
	for(current in _tasks) {
		if([document isEqual:[[[[current taskInfo] inputTracks] objectAtIndex:0] document]])
			return YES;
	}
	
	return NO;
}

- (void) stopEncoderTasksForDocument:(CompactDiscDocument *)document
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [_tasks reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		if([document isEqual:[[[[current taskInfo] inputTracks] objectAtIndex:0] document]])
			[current stop];
	}
	_freeze = NO;
}

#pragma mark mark Action Methods

- (IBAction) stopSelectedTasks:(id)sender
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController selectedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject]))
		[current stop];

	_freeze = NO;
}

- (IBAction) stopAllTasks:(id)sender
{
	NSEnumerator		*enumerator;
	EncoderTask			*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject]))
		[current stop];

	_freeze = NO;
}

#pragma mark Callbacks

- (void) encoderTaskDidStart:(EncoderTask *)task
{
	[self encoderTaskDidStart:task notify:YES];
}

- (void) encoderTaskDidStop:(EncoderTask *)task
{
	[self encoderTaskDidStop:task notify:YES];
}

- (void) encoderTaskDidComplete:(EncoderTask *)task
{
	[self encoderTaskDidComplete:task notify:YES];
}

- (void) encoderTaskDidStart:(EncoderTask *)task notify:(BOOL)notify
{
	if(NO == notify)
		return;
	
	NSString	*trackName		= [task description];
	NSString	*type			= [task outputFormatName];
	NSString	*settings		= [task encoderSettingsString];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode started for %@ [%@]", @"Log", @""), trackName, type]];
	if(nil != settings)
		[LogController logMessage:settings];

	NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
	notification.title = NSLocalizedStringFromTable(@"Encode started", @"Log", @"");
	notification.informativeText = [NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]];
	[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void) encoderTaskDidStop:(EncoderTask *)task notify:(BOOL)notify
{
	if(notify) {
		NSString	*trackName		= [task description];
		NSString	*type			= [task outputFormatName];
		
		[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode stopped for %@ [%@]", @"Log", @""), trackName, type]];
		NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
		notification.title = NSLocalizedStringFromTable(@"Encode stopped", @"Log", @"");
		notification.informativeText = [NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]];
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	}
	
	[self removeTask:task];
	[self spawnThreads];
}

- (void) encoderTaskDidComplete:(EncoderTask *)task notify:(BOOL)notify
{
	BOOL			justNotified	= NO;

	if(notify) {
		NSDate			*startTime		= [task startTime];
		NSDate			*endTime		= [task endTime];
		unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
		NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
		NSString		*trackName		= [task description];
		NSString		*type			= [task outputFormatName];
		
		[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode completed for %@ [%@]", @"Log", @""), trackName, type]];
		NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
		notification.title = NSLocalizedStringFromTable(@"Encode completed", @"Log", @"");
		notification.informativeText = [NSString stringWithFormat:@"%@\n%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type], [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]];
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	}
	
	[task retain];
	
	[self removeTask:task];
	[self spawnThreads];
	
	if(notify && 0 != [[[task taskInfo] inputTracks] count] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] ripInProgress] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] encodeInProgress]) {
		NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
		notification.title = NSLocalizedStringFromTable(@"Disc encoding completed", @"Log", @"");
		notification.informativeText = [NSString stringWithFormat:NSLocalizedStringFromTable(@"All encoding tasks completed for %@", @"Log", @""), [[[task taskInfo] metadata] albumTitle]];
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
		justNotified = YES;
	}

	// No more tasks in any queues
	if(notify && NO == [self hasTasks] && NO == [[RipperController sharedController] hasTasks]) {

		// Bounce dock icon if we're not the active application
		if(NO == [[NSApplication sharedApplication] isActive])
			[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];			
		
		// Try to avoid notification floods
		if(NO == justNotified) {
			NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
			notification.title = NSLocalizedStringFromTable(@"Disc encoding completed", @"Log", @"");
			notification.informativeText = NSLocalizedStringFromTable(@"All encoding tasks completed", @"Log", @"");
			[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
		}
	}

	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"closeWindowAfterEncoding"] && 0 != [[[task taskInfo] inputTracks] count] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] ripInProgress] && NO == [[[[[task taskInfo] inputTracks] objectAtIndex:0] document] encodeInProgress]) {
		CompactDiscDocument		*doc	= [[[[task taskInfo] inputTracks] objectAtIndex:0] document];
		[doc saveDocument:self];
		[[doc windowForSheet] performClose:self];
	}
	
	[task release];
}

#pragma mark Task Management

- (NSUInteger)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }

@end

@implementation EncoderController (Private)

- (void) runEncoder:(Class)encoderClass taskInfo:(TaskInfo *)taskInfo encoderSettings:(NSDictionary *)encoderSettings
{
	// Create the task
	EncoderTask *encoderTask = [[encoderClass alloc] init];
	
	// Set the task info
	[encoderTask setTaskInfo:taskInfo];
	
	// Pass the encoding configuration parameters
	[encoderTask setEncoderSettings:encoderSettings];
	
	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"])
		[[self window] orderFront:self];
	
	// Add the encoder to our list of encoding tasks
	[self addTask:[encoderTask autorelease]];
	[self spawnThreads];
}

- (void)		addTask:(EncoderTask *)task				{ [[self mutableArrayValueForKey:@"tasks"] addObject:task]; }

- (void) removeTask:(EncoderTask *)task
{
	[[self mutableArrayValueForKey:@"tasks"] removeObject:task];
	
	// Hide the window if no more tasks
	if(NO == [self hasTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"])
		[[self window] performClose:self];
}

- (void) spawnThreads
{
	NSUInteger	maxThreads		= (NSUInteger) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];
	NSUInteger	i;
	NSUInteger	limit;
	
	if(0 == [_tasks count] || _freeze)
		return;
	
	limit = (maxThreads < [_tasks count] ? maxThreads : [_tasks count]);
	
	// Start encoding the next track(s)
	for(i = 0; i < limit; ++i) {
		if(NO == [[_tasks objectAtIndex:i] started])
			[[_tasks objectAtIndex:i] run];
	}	
}

@end
