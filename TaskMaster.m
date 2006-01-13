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
- (void) runEncoder:(Class)encoderClass outputFilename:(NSString *)outputFilename task:(PCMGeneratingTask *)task;
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
			@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to load %@", @"Exceptions", @""), @"TaskMasterDefaults.plist"] userInfo:nil];
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

		_maxConverterThreads	= (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumConverterThreads"];
		_maxEncoderThreads		= (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];

		_useDynamicWindows		= [[NSUserDefaults standardUserDefaults] boolForKey:@"useDynamicWindows"];
		
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
- (BOOL)		hasRippingTasks								{ @synchronized(_rippingTasks) { return (0 != [_rippingTasks count]); } }
- (BOOL)		hasConvertingTasks							{ @synchronized(_convertingTasks) { return (0 != [_convertingTasks count]); } }
- (BOOL)		hasEncodingTasks							{ @synchronized(_encodingTasks) { return (0 != [_encodingTasks count]);	 } }

- (IBAction) stopAllRippingTasks:(id)sender
{
	NSArray	*tasks;
	
	@synchronized(_rippingTasks) {
		tasks = [NSArray arrayWithArray:_rippingTasks];
	}
	
	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (IBAction) stopAllConvertingTasks:(id)sender
{
	NSArray	*tasks;
	
	@synchronized(_convertingTasks) {
		tasks = [NSArray arrayWithArray:_convertingTasks];
	}
	
	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (IBAction) stopAllEncodingTasks:(id)sender
{
	NSArray	*tasks;
	
	@synchronized(_encodingTasks) {
		tasks = [NSArray arrayWithArray:_encodingTasks];
	}
	
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
	
	@synchronized(_rippingTasks) {
		enumerator = [_rippingTasks objectEnumerator];
		while((ripperTask = [enumerator nextObject])) {
			if([document isEqual:[[[ripperTask valueForKey:@"tracks"] objectAtIndex:0] getCompactDiscDocument]]) {
				return YES;
			}
		}
	}
	
	return NO;
}

- (void) stopRippingTasksForCompactDiscDocument:(CompactDiscDocument *)document
{
	RipperTask			*ripperTask;
	int					i;
	NSMutableArray		*tasks				= [NSMutableArray arrayWithCapacity:[_rippingTasks count]];
	
	@synchronized(_rippingTasks) {
		for(i = [_rippingTasks count] - 1; 0 <= i; --i) {
			ripperTask = [_rippingTasks objectAtIndex:i];
			if([document isEqual:[[[ripperTask valueForKey:@"tracks"] objectAtIndex:0] getCompactDiscDocument]]) {
				[tasks addObject:ripperTask];
			}
		}
	}

	[tasks makeObjectsPerformSelector:@selector(stop)];
}

- (void) encodeTrack:(Track *)track outputBasename:(NSString *)basename
{
	[self encodeTracks:[NSArray arrayWithObjects:track, nil] outputBasename:basename metadata:[track metadata]];
}

- (void) encodeTracks:(NSArray *)tracks outputBasename:(NSString *)basename metadata:(AudioMetadata *)metadata
{
	RipperTask	*ripperTask		= nil;

	// Verify an output format is selected
	if(NO == [self verifyOutputFormats]) {
		return;
	}
		
	// Start rip
	ripperTask = [[RipperTask alloc] initWithTracks:tracks metadata:metadata];
	[ripperTask setValue:basename forKey:@"basename"];
	
	// Show the ripper window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && _useDynamicWindows) {
		[[_ripperController window] orderFront:self];
	}
	
	// Add the ripper to our list of ripping tasks
	[self addRippingTask:[ripperTask autorelease]];
	[self spawnRipperThreads];
}

- (void) encodeFile:(NSString *)filename outputBasename:(NSString *)basename metadata:(AudioMetadata *)metadata
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

	[converterTask setValue:basename forKey:@"basename"];
	
	// Show the converter window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && _useDynamicWindows) {
		[[_converterController window] orderFront:self];
	}
	
	// Add the converter to our list of converting tasks
	[self addConvertingTask:[converterTask autorelease]];
	[self spawnConverterThreads];
}

#pragma mark Ripping functionality

- (void) addRippingTask:(RipperTask *)task
{
//	@synchronized(_rippingTasks) {
		[[self mutableArrayValueForKey:@"rippingTasks"] addObject:task];
//	}
}

- (void) removeRippingTask:(RipperTask *)task
{
	// Remove from the list of ripping tasks
	@synchronized(_rippingTasks) {
		if([_rippingTasks containsObject:task]) {
			
			[[self mutableArrayValueForKey:@"rippingTasks"] removeObject:task];
			
			// Hide the ripper window if no more tasks
			if(NO == [self hasRippingTasks] && _useDynamicWindows) {
				[[_ripperController window] performClose:self];
			}
		}
	}
}

- (void) spawnRipperThreads
{
	NSMutableArray	*activeDrives = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator	*enumerator;
	RipperTask		*task;
	NSString		*deviceName;
	
	@synchronized(_rippingTasks) {
		// Iterate through all ripping tasks once and determine which devices are active
		enumerator = [_rippingTasks objectEnumerator];
		while((task = [enumerator nextObject])) {
			deviceName = [[task valueForKey:@"ripper"] deviceName];
			if([[task valueForKeyPath:@"started"] boolValue] && NO == [activeDrives containsObject:deviceName]) {
				[activeDrives addObject:deviceName];
			}
		}
		
		// Iterate through a second time and spawn threads for non-active devices
		enumerator = [_rippingTasks objectEnumerator];
		while((task = [enumerator nextObject])) {
			deviceName = [[task valueForKey:@"ripper"] deviceName];
			if(NO == [[task valueForKeyPath:@"started"] boolValue] && NO == [activeDrives containsObject:deviceName]) {
				[activeDrives addObject:deviceName];
				[NSThread detachNewThreadSelector:@selector(run:) toTarget:task withObject:self];
			}
		}
	}
}

- (void) ripDidStart:(RipperTask* ) task
{
	NSString *trackName = [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Rip started for %@", trackName]];
//	[GrowlApplicationBridge notifyWithTitle:@"Rip started" description:trackName
//						   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripDidStop:(RipperTask* ) task
{
	NSString *trackName = [task description];

	[LogController logMessage:[NSString stringWithFormat:@"Rip stopped for %@", trackName]];
//	[GrowlApplicationBridge notifyWithTitle:@"Rip stopped" description:trackName
//						   notificationName:@"Rip stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

}

- (void) ripDidComplete:(RipperTask* ) task
{
	NSDate			*startTime		= [task valueForKey:@"startTime"];
	NSDate			*endTime		= [task valueForKey:@"endTime"];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*trackName		= [task description];
		
	[LogController logMessage:[NSString stringWithFormat:@"Rip completed for %@", trackName]];
//	[GrowlApplicationBridge notifyWithTitle:@"Rip completed" description:[NSString stringWithFormat:@"%@\nDuration: %@", trackName, duration]
//						   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	if(NO == [self hasRippingTasks]) {
//		[GrowlApplicationBridge notifyWithTitle:@"Ripping completed" description:@"All ripping tasks completed"
//							   notificationName:@"Ripping completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
	
	[self runEncodersForTask:task];
}

- (void) ripFinished:(RipperTask *)task
{
	[self removeRippingTask:task];
	[self spawnRipperThreads];
}

#pragma mark Converting Functionality

- (void) addConvertingTask:(ConverterTask *)task
{
//	@synchronized(_convertingTasks) {
		[[self mutableArrayValueForKey:@"convertingTasks"] addObject:task];
//	}
}

- (void) removeConvertingTask:(ConverterTask *) task
{
	// Remove from the list of converting tasks
	@synchronized(_convertingTasks) {
		if([_convertingTasks containsObject:task]) {

			[[self mutableArrayValueForKey:@"convertingTasks"] removeObject:task];
			
			// Hide the converter window if no more tasks
			if(NO == [self hasConvertingTasks] && _useDynamicWindows) {
				[[_converterController window] performClose:self];
			}
		}
	}
}

- (void) spawnConverterThreads
{
	unsigned	i;
	unsigned	limit;
	
	@synchronized(_convertingTasks) {
		limit = (_maxConverterThreads < [_convertingTasks count] ? _maxConverterThreads : [_convertingTasks count]);
		
		// Start converting the next file(s)
		for(i = 0; i < limit; ++i) {
			if(NO == [[[_convertingTasks objectAtIndex:i] valueForKey:@"started"] boolValue]) {
				[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_convertingTasks objectAtIndex:i] withObject:self];
			}
		}	
	}
}

- (void) convertDidStart:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Convert started for %@", filename]];
//	[GrowlApplicationBridge notifyWithTitle:@"Convert started" description:filename
//						   notificationName:@"Convert started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) convertDidStop:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Convert stopped for %@", filename]];
//	[GrowlApplicationBridge notifyWithTitle:@"Convert stopped" description:filename
//						   notificationName:@"Convert stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) convertDidComplete:(ConverterTask* ) task
{
	NSDate			*startTime		= [task valueForKey:@"startTime"];
	NSDate			*endTime		= [task valueForKey:@"endTime"];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*filename		= [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Convert completed for %@", filename]];
//	[GrowlApplicationBridge notifyWithTitle:@"Convert completed" description:[NSString stringWithFormat:@"%@\nDuration: %@", filename, duration]
//						   notificationName:@"Convert completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self runEncodersForTask:task];	
}

- (void) convertFinished:(ConverterTask *)task
{
	[self removeConvertingTask:task];
	[self spawnConverterThreads];
	
	if(NO == [self hasConvertingTasks]) {
//		[GrowlApplicationBridge notifyWithTitle:@"Conversion completed" description:@"All converting tasks completed"
//							   notificationName:@"Conversion completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
}

#pragma mark Encoding functionality

- (void) runEncodersForTask:(PCMGeneratingTask *)task
{
	NSArray			*libsndfileFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"libsndfileOutputFormats"];
	NSArray			*coreAudioFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"coreAudioOutputFormats"];
	NSString		*outputFilename		= nil;

	// Create encoder tasks for the rip that just completed
	@try {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputMP3"]) {
			outputFilename = generateUniqueFilename([task valueForKey:@"basename"], @"mp3");
			[self runEncoder:[MPEGEncoderTask class] outputFilename:outputFilename task:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputFLAC"]) {
			outputFilename = generateUniqueFilename([task valueForKey:@"basename"], @"flac");
			[self runEncoder:[FLACEncoderTask class] outputFilename:outputFilename task:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggFLAC"]) {
			outputFilename = generateUniqueFilename([task valueForKey:@"basename"], @"oggflac");
			[self runEncoder:[OggFLACEncoderTask class] outputFilename:outputFilename task:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggVorbis"]) {
			outputFilename = generateUniqueFilename([task valueForKey:@"basename"], @"ogg");
			[self runEncoder:[OggVorbisEncoderTask class] outputFilename:outputFilename task:task];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputSpeex"]) {
			outputFilename = generateUniqueFilename([task valueForKey:@"basename"], @"spx");
			[self runEncoder:[SpeexEncoderTask class] outputFilename:outputFilename task:task];
		}
		
		// Core Audio encoders
		if(nil != coreAudioFormats && 0 < [coreAudioFormats count]) {
			EncoderTask		*encoderTask;
			NSEnumerator	*formats		= [coreAudioFormats objectEnumerator];
			NSDictionary	*formatInfo;
			id				extensions;
			NSString		*extension;
			
			while((formatInfo = [formats nextObject])) {
				extensions		= [formatInfo valueForKey:@"extensionsForType"];
				if([extensions isKindOfClass:[NSArray class]]) {
					extension = [extensions objectAtIndex:0];
				}
				else {
					extension = extensions;
				}
				
				outputFilename	= generateUniqueFilename([task valueForKey:@"basename"], extension);
				encoderTask		= [[CoreAudioEncoderTask alloc] initWithTask:task outputFilename:outputFilename metadata:[task metadata] formatInfo:formatInfo];
				
				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden] && _useDynamicWindows) {
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
				outputFilename			= generateUniqueFilename([task valueForKey:@"basename"], [formatInfo valueForKey:@"extension"]);
				
				EncoderTask *encoderTask = [[LibsndfileEncoderTask alloc] initWithTask:task outputFilename:outputFilename metadata:[task metadata] formatInfo:formatInfo];

				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden] && _useDynamicWindows) {
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

- (void) runEncoder:(Class)encoderClass outputFilename:(NSString *)outputFilename task:(PCMGeneratingTask *)task
{
	// Create the encoder (relies on each subclass having the same method signature)
	EncoderTask *encoderTask = [[encoderClass alloc] initWithTask:task outputFilename:outputFilename metadata:[task metadata]];
		
	if([task isKindOfClass:[RipperTask class]]) {
		[encoderTask setTracks:[task valueForKey:@"tracks"]];
	}

	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden] && _useDynamicWindows) {
		[[_encoderController window] orderFront:self];
	}
	
	// Add the encoder to our list of encoding tasks
	[self addEncodingTask:[encoderTask autorelease]];
	[self spawnEncoderThreads];
}

- (void) addEncodingTask:(EncoderTask *)task
{
//	@synchronized(_encodingTasks) {
		[[self mutableArrayValueForKey:@"encodingTasks"] addObject:task];
//	}
}

- (void) removeEncodingTask:(EncoderTask *)task
{
	// Remove from the list of encoding tasks
	@synchronized(_encodingTasks) {
		if([_encodingTasks containsObject:task]) {

			[[self mutableArrayValueForKey:@"encodingTasks"] removeObject:task];

			// Hide the encoder window if no more tasks
			if(NO == [self hasEncodingTasks] && _useDynamicWindows) {
				[[_encoderController window] performClose:self];
			}
		}	
	}
}

- (void) spawnEncoderThreads
{
	unsigned	i;
	unsigned	limit;
	
	@synchronized(_encodingTasks) {
		limit = (_maxEncoderThreads < [_encodingTasks count] ? _maxEncoderThreads : [_encodingTasks count]);
		
		// Start encoding the next track(s)
		for(i = 0; i < limit; ++i) {
			if(NO == [[[_encodingTasks objectAtIndex:i] valueForKeyPath:@"started"] boolValue]) {
				[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_encodingTasks objectAtIndex:i] withObject:self];
			}
		}	
	}
}

- (void) encodeDidStart:(EncoderTask* ) task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task getType];
	NSString	*settings		= [task valueForKeyPath:@"encoder.description"];

	[LogController logMessage:[NSString stringWithFormat:@"Encode started for %@ [%@]", trackName, type]];
	if(nil != settings) {
		[LogController logMessage:settings];
	}
//	[GrowlApplicationBridge notifyWithTitle:@"Encode started" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
//						   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encodeDidStop:(EncoderTask* ) task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task getType];

	[LogController logMessage:[NSString stringWithFormat:@"Encode stopped for %@ [%@]", trackName, type]];
//	[GrowlApplicationBridge notifyWithTitle:@"Encode stopped" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
//						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encodeDidComplete:(EncoderTask* ) task
{
	NSDate			*startTime		= [task valueForKey:@"startTime"];
	NSDate			*endTime		= [task valueForKey:@"endTime"];
	unsigned int	timeInSeconds	= (unsigned int) [endTime timeIntervalSinceDate:startTime];
	NSString		*duration		= [NSString stringWithFormat:@"%i:%02i", timeInSeconds / 60, timeInSeconds % 60];
	NSString		*trackName		= [task description];
	NSString		*type			= [task getType];
	
	[LogController logMessage:[NSString stringWithFormat:@"Encode completed for %@ [%@]", trackName, type]];
//	[GrowlApplicationBridge notifyWithTitle:@"Encode completed" description:[NSString stringWithFormat:@"%@\nFile format: %@\nDuration: %@", trackName, type, duration]
//						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	if(NO == [self hasEncodingTasks]) {
//		[GrowlApplicationBridge notifyWithTitle:@"Encoding completed" description:@"All encoding tasks completed"
//							   notificationName:@"Encoding completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	}
}

- (void) encodeFinished:(EncoderTask *)task
{
	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
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
		[alert addButtonWithTitle: @"OK"];
		[alert addButtonWithTitle: @"Show Preferences"];
		[alert setMessageText:@"No output formats selected"];
		[alert setInformativeText:@"Please select one or more output formats."];
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
