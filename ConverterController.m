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

#import "ConverterController.h"
#import "CoreAudioConverterTask.h"
#import "LibsndfileConverterTask.h"
#import "OggVorbisConverterTask.h"
#import "FLACConverterTask.h"
#import "OggFLACConverterTask.h"
#import "MonkeysAudioConverterTask.h"
#import "SpeexConverterTask.h"
#import "UtilityFunctions.h"
#import "CoreAudioUtilities.h"
#import "LogController.h"
#import "EncoderController.h"
#import "ApplicationController.h"
#import "IOException.h"
#import "FileFormatNotSupportedException.h"

#import <Growl/GrowlApplicationBridge.h>

#include <paths.h>			// _PATH_TMP
#include <sys/param.h>		// statfs
#include <sys/mount.h>

static ConverterController *sharedController = nil;

@interface ConverterController (Private)
- (void)	updateFreeSpace:(NSTimer *)theTimer;
- (void)	addTask:(ConverterTask *)task;
- (void)	removeTask:(ConverterTask *)task;
- (void)	spawnThreads;
@end

@implementation ConverterController

+ (ConverterController *) sharedController
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
	if((self = [super initWithWindowNibName:@"Converter"])) {
		
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
	[self setWindowFrameAutosaveName:@"Converter"];
	[[self window] setExcludedFromWindowsMenu:YES];

	[[self window] registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
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

- (void) convertFile:(NSString *)filename metadata:(AudioMetadata *)metadata
{
	ConverterTask	*converterTask			= nil;
	NSArray			*coreAudioExtensions	= getCoreAudioExtensions();
	NSArray			*libsndfileExtensions	= getLibsndfileExtensions();
	NSString		*extension				= [filename pathExtension];
	
	// Verify an output format is selected
	if(YES == [[ApplicationController sharedController] displayAlertIfNoOutputFormats]) {
		return;
	}
	
	// Determine which type of converter to use and create it
	if([coreAudioExtensions containsObject:extension]) {
		converterTask = [[CoreAudioConverterTask alloc] initWithInputFile:filename metadata:metadata];		
	}
	else if([libsndfileExtensions containsObject:extension]) {
		converterTask = [[LibsndfileConverterTask alloc] initWithInputFile:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"ogg"]) {
		converterTask = [[OggVorbisConverterTask alloc] initWithInputFile:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"flac"]) {
		converterTask = [[FLACConverterTask alloc] initWithInputFile:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"oggflac"]) {
		converterTask = [[OggFLACConverterTask alloc] initWithInputFile:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"ape"] || [extension isEqualToString:@"apl"] || [extension isEqualToString:@"mac"]) {
		converterTask = [[MonkeysAudioConverterTask alloc] initWithInputFile:filename metadata:metadata];
	}
	else if([extension isEqualToString:@"spx"]) {
		converterTask = [[SpeexConverterTask alloc] initWithInputFile:filename metadata:metadata];		
	}
	else {
		@throw [FileFormatNotSupportedException exceptionWithReason:NSLocalizedStringFromTable(@"The file's format was not recognized.", @"Exceptions", @"") 
														   userInfo:[NSDictionary dictionaryWithObject:filename forKey:@"filename"]];
	}
	
	// Show the converter window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] orderFront:self];
	}
	
	// Add the converter to our list of converting tasks
	[self addTask:[converterTask autorelease]];
	[self spawnThreads];
}

#pragma Action Methods

- (IBAction) stopSelectedTasks:(id)sender
{
	NSEnumerator		*enumerator;
	ConverterTask		*current;
	
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
	ConverterTask		*current;
	
	_freeze = YES;
	enumerator = [[_tasksController arrangedObjects] reverseObjectEnumerator];
	while((current = [enumerator nextObject])) {
		[current stop];
	}
	_freeze = NO;
}

#pragma mark Callbacks

- (void) converterTaskDidStart:(ConverterTask *)task
{
	NSString	*filename		= [task description];
	NSString	*type			= [task inputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Convert started for %@ [%@]", @"Log", @""), filename, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Convert started", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", filename, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Convert started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) converterTaskDidStop:(ConverterTask *)task
{
	NSString	*filename		= [task description];
	NSString	*type			= [task inputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Convert stopped for %@ [%@]", @"Log", @""), filename, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Convert stopped", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", filename, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Convert stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
}

- (void) converterTaskDidComplete:(ConverterTask *)task
{
	NSDate			*startTime		= [task startTime];
	NSDate			*endTime		= [task endTime];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*filename		= [task description];
	NSString		*type			= [task inputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Convert completed for %@ [%@]", @"Log", @""), filename, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Convert completed", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@\n%@", filename, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type], [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]]
						   notificationName:@"Convert completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeTask:task];
	[self spawnThreads];
	
	if(NO == [self hasTasks]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Conversion completed", @"Log", @"")
									description:NSLocalizedStringFromTable(@"All converting tasks completed", @"Log", @"")
							   notificationName:@"Conversion completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
	
	[[EncoderController sharedController] runEncodersForTask:task];
}

#pragma mark Task Management

- (unsigned)	countOfTasks							{ return [_tasks count]; }
- (BOOL)		hasTasks								{ return (0 != [_tasks count]); }
- (void)		addTask:(ConverterTask *)task			{ [_tasksController addObject:task]; }

- (void) removeTask:(ConverterTask *)task
{
	[_tasksController removeObject:task];
	
	// Hide the window if no more tasks
	if(NO == [self hasTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[self window] performClose:self];
	}
}

- (void) spawnThreads
{
	int		maxThreads			= [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumConverterThreads"];
	int		i, limit, delta;
	
	if(0 == [_tasks count] || _freeze) {
		return;
	}
	
	limit = (maxThreads < (int)[_tasks count] ? maxThreads : (int)[_tasks count]);
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"balanceConverters"]) {
		delta = 2 * [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"] - [[EncoderController sharedController] countOfTasks];
		limit = (limit <= delta ? limit : delta);
	}
	
	for(i = 0; i < limit; ++i) {
		if(NO == [[_tasks objectAtIndex:i] started]) {
			[[_tasks objectAtIndex:i] run];
		}
	}
}

@end
