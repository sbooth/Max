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

#import "TaskMaster.h"
#import "LogController.h"
#import "PreferencesController.h"
#import "RipperTask.h"
#import "CoreAudioConverterTask.h"
#import "LibsndfileConverterTask.h"
#import "OggVorbisConverterTask.h"
#import "FLACConverterTask.h"
#import "OggFLACConverterTask.h"
#import "SpeexConverterTask.h"
#import "MPEGEncoderTask.h"
#import "FLACEncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "CoreAudioEncoderTask.h"
#import "LibsndfileEncoderTask.h"
#import "SpeexEncoderTask.h"
#import "MissingResourceException.h"
#import "IOException.h"
#import "FileFormatNotSupportedException.h"
#import "UtilityFunctions.h"
#import "CoreAudioUtilities.h"

#import <Growl/GrowlApplicationBridge.h>


static TaskMaster *sharedController = nil;

@interface TaskMaster (Private)
- (void) spawnRipperThreads;
- (void) spawnConverterThreads;
- (void) spawnEncoderThreads;
- (void) addRippingTask:(RipperTask *) task;
- (void) addConvertingTask:(ConverterTask *) task;
- (void) addEncodingTask:(EncoderTask *) task;
- (void) removeRippingTask:(RipperTask *) task;
- (void) removeConvertingTask:(ConverterTask *) task;
- (void) removeEncodingTask:(EncoderTask *) task;
- (void) runEncodersForTask:(PCMGeneratingTask *)task;
- (void) runEncoder:(Class)encoderClass forTask:(PCMGeneratingTask *)task;
- (void) alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(void *) contextInfo;
- (BOOL) outputFormatsSelected;
- (BOOL) verifyOutputFormats;
@end

@implementation TaskMaster

+ (void) initialize
{
	NSString				*taskMasterDefaultsValuesPath;
    NSDictionary			*taskMasterDefaultsValuesDictionary;
    
	@try {
		taskMasterDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"TaskMasterDefaults" ofType:@"plist"];
		if(nil == taskMasterDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"TaskMasterDefaults.plist" forKey:@"filename"]];
		}
		taskMasterDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:taskMasterDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:taskMasterDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) init
{
	if((self = [super init])) {
		
		_rippingTasks			= [[NSMutableArray arrayWithCapacity:20] retain];
		_convertingTasks		= [[NSMutableArray arrayWithCapacity:20] retain];
		_encodingTasks			= [[NSMutableArray arrayWithCapacity:20] retain];

		_ripperController		= [[RipperController sharedController] retain];
		_converterController	= [[ConverterController sharedController] retain];
		_encoderController		= [[EncoderController sharedController] retain];
		
		// Avoid infinite loops in init
		[_ripperController setValue:self forKey:@"taskMaster"];
		[_converterController setValue:self forKey:@"taskMaster"];
		[_encoderController setValue:self forKey:@"taskMaster"];
		
		return self;
	}
	return nil;
}

+ (TaskMaster *) sharedController
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

- (void) dealloc
{
	[self stopAllTasks:self];

	[_ripperController release];
	[_converterController release];
	[_encoderController release];
	
	[_rippingTasks release];
	[_convertingTasks release];
	[_encodingTasks release];
	
	[super dealloc];
}

- (void) displayExceptionSheet:(NSException *) exception
{
	displayExceptionAlert(exception);
}

- (void) alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(void *) contextInfo
{}

#pragma mark Task Management

- (BOOL)		hasTasks									{ return ([self hasRippingTasks] || [self hasConvertingTasks] || [self hasEncodingTasks]); }
- (BOOL)		hasRippingTasks								{ return (0 != [_rippingTasks count]); }
- (BOOL)		hasConvertingTasks							{ return (0 != [_convertingTasks count]); }
- (BOOL)		hasEncodingTasks							{ return (0 != [_encodingTasks count]);	 }

- (IBAction) stopAllRippingTasks:(id)sender
{
	NSArray	*tasks = [NSArray arrayWithArray:_rippingTasks];
	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (IBAction) stopAllConvertingTasks:(id)sender
{
	NSArray	*tasks = [NSArray arrayWithArray:_convertingTasks];
	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (IBAction) stopAllEncodingTasks:(id)sender
{
	NSArray	*tasks = [NSArray arrayWithArray:_encodingTasks];
	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (IBAction) stopAllTasks:(id)sender
{
	[self stopAllRippingTasks:sender];
	[self stopAllConvertingTasks:sender];
	[self stopAllEncodingTasks:sender];
}

- (BOOL) compactDiscDocumentHasRippingTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator;
	RipperTask		*ripperTask;
	
	enumerator = [_rippingTasks objectEnumerator];
	while((ripperTask = [enumerator nextObject])) {
		if([document isEqual:[[[ripperTask tracks] objectAtIndex:0] getCompactDiscDocument]]) {
			return YES;
		}
	}
	
	return NO;
}

- (BOOL) compactDiscDocumentHasEncodingTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator;
	EncoderTask		*encoderTask;
	
	enumerator = [_encodingTasks objectEnumerator];
	while((encoderTask = [enumerator nextObject])) {
		if(nil != [encoderTask tracks] && [document isEqual:[[[encoderTask tracks] objectAtIndex:0] getCompactDiscDocument]]) {
			return YES;
		}
	}
	
	return NO;
}

- (void) stopRippingTasksForCompactDiscDocument:(CompactDiscDocument *)document
{
	RipperTask			*ripperTask;
	int					i;
	NSMutableArray		*tasks				= [NSMutableArray arrayWithCapacity:[_rippingTasks count]];
	
	for(i = [_rippingTasks count] - 1; 0 <= i; --i) {
		ripperTask = [_rippingTasks objectAtIndex:i];
		if([document isEqual:[[[ripperTask valueForKey:@"tracks"] objectAtIndex:0] getCompactDiscDocument]]) {
			[tasks addObject:ripperTask];
		}
	}

	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (void) encodeTrack:(Track *)track
{
	[self encodeTracks:[NSArray arrayWithObjects:track, nil] metadata:[track metadata]];
}

- (void) encodeTracks:(NSArray *)tracks metadata:(AudioMetadata *)metadata
{
	RipperTask	*ripperTask		= nil;

	// Verify an output format is selected
	if(NO == [self verifyOutputFormats]) {
		return;
	}
		
	// Start rip
	ripperTask = [[RipperTask alloc] initWithTracks:tracks metadata:metadata];
	
	// Show the ripper window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[_ripperController window] orderFront:self];
	}
	
	// Add the ripper to our list of ripping tasks
	[self addRippingTask:[ripperTask autorelease]];
	[self spawnRipperThreads];
}

- (void) encodeFile:(NSString *)filename metadata:(AudioMetadata *)metadata
{
	ConverterTask	*converterTask			= nil;
	NSArray			*coreAudioExtensions	= getCoreAudioExtensions();
	NSArray			*libsndfileExtensions	= getLibsndfileExtensions();
	NSString		*extension				= [filename pathExtension];
	
	// Verify an output format is selected
	if(NO == [self verifyOutputFormats]) {
		return;
	}

	// Determine which type of converter to use and create it
	if([coreAudioExtensions containsObject:extension]) {
		converterTask = [[CoreAudioConverterTask alloc] initWithInputFilename:filename metadata:metadata];		
	}
	else if([libsndfileExtensions containsObject:extension]) {
		converterTask = [[LibsndfileConverterTask alloc] initWithInputFilename:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"ogg"]) {
		converterTask = [[OggVorbisConverterTask alloc] initWithInputFilename:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"flac"]) {
		converterTask = [[FLACConverterTask alloc] initWithInputFilename:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"oggflac"]) {
		converterTask = [[OggFLACConverterTask alloc] initWithInputFilename:filename metadata:metadata];		
	}
	else if([extension isEqualToString:@"spx"]) {
		converterTask = [[SpeexConverterTask alloc] initWithInputFilename:filename metadata:metadata];		
	}
	else {
		@throw [FileFormatNotSupportedException exceptionWithReason:NSLocalizedStringFromTable(@"File format not supported", @"Exceptions", @"") userInfo:nil];
	}
	
	// Show the converter window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[_converterController window] orderFront:self];
	}
	
	// Add the converter to our list of converting tasks
	[self addConvertingTask:[converterTask autorelease]];
	[self spawnConverterThreads];
}

#pragma mark Ripping functionality

- (void) addRippingTask:(RipperTask *)task
{
	[[self mutableArrayValueForKey:@"rippingTasks"] addObject:task];
}

- (void) removeRippingTask:(RipperTask *)task
{
	// Remove from the list of ripping tasks
	if([_rippingTasks containsObject:task]) {
		
		[[self mutableArrayValueForKey:@"rippingTasks"] removeObject:task];
		
		// Hide the ripper window if no more tasks
		if(NO == [self hasRippingTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
			[[_ripperController window] performClose:self];
		}
	}
}

- (void) spawnRipperThreads
{
	NSMutableArray	*activeDrives = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator	*enumerator;
	RipperTask		*task;
	NSString		*deviceName;
	
	// Iterate through all ripping tasks once and determine which devices are active
	enumerator = [_rippingTasks objectEnumerator];
	while((task = [enumerator nextObject])) {
		deviceName = [task deviceName];
		if([task started] && NO == [activeDrives containsObject:deviceName]) {
			[activeDrives addObject:deviceName];
		}
	}
	
	// Iterate through a second time and spawn threads for non-active devices
	enumerator = [_rippingTasks objectEnumerator];
	while((task = [enumerator nextObject])) {
		deviceName = [task deviceName];
		if(NO == [task started] && NO == [activeDrives containsObject:deviceName]) {
			[activeDrives addObject:deviceName];
			[task run];
		}
	}
}

- (void) ripDidStart:(RipperTask* ) task
{
	NSString *trackName = [task description];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip started for %@", @"Log", @""), trackName]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Rip started", @"Log", @"") description:trackName
						   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripDidStop:(RipperTask* ) task
{
	NSString *trackName = [task description];

	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip stopped for %@", @"Log", @""), trackName]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Rip stopped", @"Log", @"") description:trackName
						   notificationName:@"Rip stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];
}

- (void) ripDidComplete:(RipperTask* ) task
{
	NSDate			*startTime		= [task startTime];
	NSDate			*endTime		= [task endTime];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*trackName		= [task description];
		
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip completed for %@", @"Log", @""), trackName]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Rip completed", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"Duration: %@", @"Log", @""), duration]]
						   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];

	if(NO == [self hasRippingTasks]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Ripping completed", @"Log", @"")
									description:NSLocalizedStringFromTable(@"All ripping tasks completed", @"Log", @"")
							   notificationName:@"Ripping completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}

	[self runEncodersForTask:task];
}

#pragma mark Converting Functionality

- (void) addConvertingTask:(ConverterTask *)task
{
	[[self mutableArrayValueForKey:@"convertingTasks"] addObject:task];
}

- (void) removeConvertingTask:(ConverterTask *) task
{
	// Remove from the list of converting tasks
	if([_convertingTasks containsObject:task]) {

		[[self mutableArrayValueForKey:@"convertingTasks"] removeObject:task];
		
		// Hide the converter window if no more tasks
		if(NO == [self hasConvertingTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
			[[_converterController window] performClose:self];
		}
	}
}

- (void) spawnConverterThreads
{
	unsigned	maxThreads	= (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumConverterThreads"];
	unsigned	i;
	unsigned	limit;

	limit = (maxThreads < [_convertingTasks count] ? maxThreads : [_convertingTasks count]);
	
	// Start converting the next file(s)
	for(i = 0; i < limit; ++i) {
		if(NO == [[_convertingTasks objectAtIndex:i] started]) {
			[[_convertingTasks objectAtIndex:i] run];
		}
	}
}

- (void) convertDidStart:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	NSString	*type			= [task inputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Convert started for %@ [%@]", @"Log", @""), filename, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Convert started", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", filename, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Convert started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) convertDidStop:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	NSString	*type			= [task inputFormat];
	
	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Convert stopped for %@ [%@]", @"Log", @""), filename, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Convert stopped", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", filename, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Convert stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeConvertingTask:task];
	[self spawnConverterThreads];
}

- (void) convertDidComplete:(ConverterTask* ) task
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
	
	[self removeConvertingTask:task];
	[self spawnConverterThreads];

	if(NO == [self hasConvertingTasks]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Conversion completed", @"Log", @"")
									description:NSLocalizedStringFromTable(@"All converting tasks completed", @"Log", @"")
							   notificationName:@"Conversion completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}

	[self runEncodersForTask:task];
}

#pragma mark Encoding functionality

- (void) runEncodersForTask:(PCMGeneratingTask *)task
{
	NSArray			*libsndfileFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"libsndfileOutputFormats"];
	NSArray			*coreAudioFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"coreAudioOutputFormats"];

	// Create encoder tasks for the rip that just completed
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
					[encoderTask setTracks:[(RipperTask *)task tracks]];
				}

				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
					[[_encoderController window] orderFront:self];
				}
				
				// Add the encoder to our list of encoding tasks
				[self addEncodingTask:[encoderTask autorelease]];
				[self spawnEncoderThreads];
			}
		}
		
		// libsndfile encoders
		if(nil != libsndfileFormats && 0 < [libsndfileFormats count]) {
			NSEnumerator	*formats		= [libsndfileFormats objectEnumerator];
			NSDictionary	*formatInfo;
			
			while((formatInfo = [formats nextObject])) {
				
				EncoderTask *encoderTask = [[LibsndfileEncoderTask alloc] initWithTask:task formatInfo:formatInfo];

				if([task isKindOfClass:[RipperTask class]]) {
					[encoderTask setTracks:[(RipperTask *)task tracks]];
				}

				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
					[[_encoderController window] orderFront:self];
				}
				
				// Add the encoder to our list of encoding tasks
				[self addEncodingTask:[encoderTask autorelease]];
				[self spawnEncoderThreads];
			}
		}
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	
	@finally {
	}
}

- (void) runEncoder:(Class)encoderClass forTask:(PCMGeneratingTask *)task
{
	// Create the encoder (relies on each subclass having the same method signature)
	EncoderTask *encoderTask = [[encoderClass alloc] initWithTask:task];

	if([task isKindOfClass:[RipperTask class]]) {
		[encoderTask setTracks:[(RipperTask *)task tracks]];
	}

	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
		[[_encoderController window] orderFront:self];
	}
	
	// Add the encoder to our list of encoding tasks
	[self addEncodingTask:[encoderTask autorelease]];
	[self spawnEncoderThreads];
}

- (void) addEncodingTask:(EncoderTask *)task
{
	[[self mutableArrayValueForKey:@"encodingTasks"] addObject:task];
}

- (void) removeEncodingTask:(EncoderTask *)task
{
	// Remove from the list of encoding tasks
	if([_encodingTasks containsObject:task]) {

		[[self mutableArrayValueForKey:@"encodingTasks"] removeObject:task];

		// Hide the encoder window if no more tasks
		if(NO == [self hasEncodingTasks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"]) {
			[[_encoderController window] performClose:self];
		}
	}
}

- (void) spawnEncoderThreads
{
	unsigned	maxThreads		= (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];
	unsigned	i;
	unsigned	limit;
	
	limit = (maxThreads < [_encodingTasks count] ? maxThreads : [_encodingTasks count]);
	
	// Start encoding the next track(s)
	for(i = 0; i < limit; ++i) {
		if(NO == [[[_encodingTasks objectAtIndex:i] valueForKeyPath:@"started"] boolValue]) {
			[[_encodingTasks objectAtIndex:i] run];
		}	
	}
}

- (void) encodeDidStart:(EncoderTask* ) task
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

- (void) encodeDidStop:(EncoderTask* ) task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task outputFormat];

	[LogController logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Encode stopped for %@ [%@]", @"Log", @""), trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encode stopped", @"Log", @"") 
								description:[NSString stringWithFormat:@"%@\n%@", trackName, [NSString stringWithFormat:NSLocalizedStringFromTable(@"File format: %@", @"Log", @""), type]]
						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
}

- (void) encodeDidComplete:(EncoderTask* ) task
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

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];

	if(NO == [self hasEncodingTasks]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedStringFromTable(@"Encoding completed", @"Log", @"")
									description:NSLocalizedStringFromTable(@"All encoding tasks completed", @"Log", @"")
							   notificationName:@"Encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
}

- (BOOL) outputFormatsSelected
{
	BOOL		outputLibsndfile	= (0 != [[[NSUserDefaults standardUserDefaults] objectForKey:@"libsndfileOutputFormats"] count]);
	BOOL		outputCoreAudio		= (0 != [[[NSUserDefaults standardUserDefaults] objectForKey:@"coreAudioOutputFormats"] count]);
	BOOL		outputMP3			= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputMP3"];
	BOOL		outputFLAC			= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputFLAC"];
	BOOL		outputOggFLAC		= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggFLAC"];
	BOOL		outputOggVorbis		= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggVorbis"];
	BOOL		outputSpeex			= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputSpeex"];

	return (outputLibsndfile || outputCoreAudio || outputMP3 || outputFLAC || outputOggFLAC || outputOggVorbis || outputSpeex);
}

- (BOOL) verifyOutputFormats
{
	// Verify at least one output format is selected
	if(NO == [self outputFormatsSelected]) {
		int result;
		
		NSBeep();

		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
		[alert setMessageText:NSLocalizedStringFromTable(@"No output formats selected", @"General", @"")];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		result = [alert runModal];
		
		if(NSAlertFirstButtonReturn == result) {
			// do nothing
		}
		else if(NSAlertSecondButtonReturn == result) {
			[[PreferencesController sharedPreferences] showWindow:self];
		}
		
		return NO;
	}
	
	return YES;
}
@end
