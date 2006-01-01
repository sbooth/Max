/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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
#import "RipperTask.h"
#import "CoreAudioConverterTask.h"
#import "LibsndfileConverterTask.h"
#import "OggVorbisConverterTask.h"
#import "FLACConverterTask.h"
#import "OggFLACConverterTask.h"
#import "MPEGEncoderTask.h"
#import "FLACEncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "CoreAudioEncoderTask.h"
#import "LibsndfileEncoderTask.h"
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
- (void) removeRippingTask:(RipperTask *) task;
- (void) removeConvertingTask:(ConverterTask *) task;
- (void) removeEncodingTask:(EncoderTask *) task;
- (void) runEncodersForTask:(PCMGeneratingTask *)task;
- (void) runEncoder:(Class)encoderClass outputFilename:(NSString *)outputFilename task:(PCMGeneratingTask *)task;
- (void) alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(void *) contextInfo;
@end

@implementation TaskMaster

+ (void) initialize
{
	NSString				*taskMasterDefaultsValuesPath;
    NSDictionary			*taskMasterDefaultsValuesDictionary;
    
	@try {
		taskMasterDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"TaskMasterDefaults" ofType:@"plist"];
		if(nil == taskMasterDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load TaskMasterDefaults.plist." userInfo:nil];
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
	NSEnumerator	*enumerator;
	RipperTask		*ripperTask;
	
	enumerator = [_rippingTasks objectEnumerator];
	while((ripperTask = [enumerator nextObject])) {
		[ripperTask stop];
	}
}

- (IBAction) stopAllConvertingTasks:(id)sender
{
	NSEnumerator	*enumerator;
	ConverterTask	*converterTask;
	
	enumerator = [_convertingTasks objectEnumerator];
	while((converterTask = [enumerator nextObject])) {
		[converterTask stop];
	}
}

- (IBAction) stopAllEncodingTasks:(id)sender
{
	NSEnumerator	*enumerator;
	EncoderTask		*encoderTask;
	
	enumerator = [_encodingTasks objectEnumerator];
	while((encoderTask = [enumerator nextObject])) {
		[encoderTask stop];
	}
}

- (IBAction) stopAllTasks:(id)sender
{
	[self stopAllRippingTasks:sender];
	[self stopAllConvertingTasks:sender];
	[self stopAllEncodingTasks:sender];
}

- (BOOL) compactDiscDocumentHasRippingTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator		= [_rippingTasks objectEnumerator];
	RipperTask		*ripperTask;
	
	while((ripperTask = [enumerator nextObject])) {
		if([document isEqual:[[[ripperTask valueForKey:@"tracks"] objectAtIndex:0] getCompactDiscDocument]]) {
			return YES;
		}
	}
	
	return NO;
}

- (void) stopRippingTasksForCompactDiscDocument:(CompactDiscDocument *)document
{
	RipperTask		*ripperTask;
	int				i;
	
	for(i = [_rippingTasks count] - 1; 0 <= i; --i) {
		ripperTask = [_rippingTasks objectAtIndex:i];
		if([document isEqual:[[[ripperTask valueForKey:@"tracks"] objectAtIndex:0] getCompactDiscDocument]]) {
			[ripperTask stop];
		}
	}
}

- (void) encodeTrack:(Track *)track outputBasename:(NSString *)basename
{
	[self encodeTracks:[NSArray arrayWithObjects:track, nil] outputBasename:basename metadata:[track metadata]];
}

- (void) encodeTracks:(NSArray *)tracks outputBasename:(NSString *)basename metadata:(AudioMetadata *)metadata
{
	RipperTask	*ripperTask		= nil;
	
	// Start rip
	ripperTask = [[RipperTask alloc] initWithTracks:tracks metadata:metadata];
	[ripperTask setValue:basename forKey:@"basename"];
	[ripperTask addObserver:self forKeyPath:@"ripper.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:ripperTask];	
	[ripperTask addObserver:self forKeyPath:@"ripper.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:ripperTask];	
	[ripperTask addObserver:self forKeyPath:@"ripper.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:ripperTask];	
	
	// Show the ripper window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden]) {
		[[_ripperController window] orderFront:self];
	}
	
	// Add the ripper to our list of ripping tasks
	[[self mutableArrayValueForKey:@"rippingTasks"] addObject:[ripperTask autorelease]];
	[self spawnRipperThreads];
}

- (void) encodeFile:(NSString *)filename outputBasename:(NSString *)basename metadata:(AudioMetadata *)metadata
{
	ConverterTask	*converterTask			= nil;
	NSArray			*coreAudioExtensions	= getCoreAudioExtensions();
	NSArray			*libsndfileExtensions	= getLibsndfileExtensions();
	NSString		*extension				= [filename pathExtension];
	
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
	else {
		@throw [FileFormatNotSupportedException exceptionWithReason:@"File format not supported" userInfo:nil];
	}

	[converterTask setValue:basename forKey:@"basename"];
	[converterTask addObserver:self forKeyPath:@"converter.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:converterTask];	
	[converterTask addObserver:self forKeyPath:@"converter.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:converterTask];	
	[converterTask addObserver:self forKeyPath:@"converter.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:converterTask];	
	
	// Show the converter window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden]) {
		[[_converterController window] orderFront:self];
	}
	
	// Add the converter to our list of converting tasks
	[[self mutableArrayValueForKey:@"convertingTasks"] addObject:[converterTask autorelease]];
	[self spawnConverterThreads];
}

- (void) observeValueForKeyPath:(NSString *) keyPath ofObject:(id) object change:(NSDictionary *) change context:(void *) context
{
	if([keyPath isEqualToString:@"ripper.started"]) {
		[self performSelectorOnMainThread:@selector(ripDidStart:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"ripper.stopped"]) {
		[self performSelectorOnMainThread:@selector(ripDidStop:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"ripper.completed"]) {
		[self performSelectorOnMainThread:@selector(ripDidComplete:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"converter.started"]) {
		[self performSelectorOnMainThread:@selector(convertDidStart:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"converter.stopped"]) {
		[self performSelectorOnMainThread:@selector(convertDidStop:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"converter.completed"]) {
		[self performSelectorOnMainThread:@selector(convertDidComplete:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"encoder.started"]) {
		[self performSelectorOnMainThread:@selector(encodeDidStart:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"encoder.stopped"]) {
		[self performSelectorOnMainThread:@selector(encodeDidStop:) withObject:context waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"encoder.completed"]) {
		[self performSelectorOnMainThread:@selector(encodeDidComplete:) withObject:context waitUntilDone:YES];
	}
}

#pragma mark Ripping functionality

- (void) removeRippingTask:(RipperTask *) task
{
	// Remove from the list of ripping tasks
	if([_rippingTasks containsObject:task]) {
		[task removeObserver:self forKeyPath:@"ripper.started"];
		[task removeObserver:self forKeyPath:@"ripper.completed"];
		[task removeObserver:self forKeyPath:@"ripper.stopped"];
		
		[[self mutableArrayValueForKey:@"rippingTasks"] removeObject:task];
		
		// Hide the ripper window if no more tasks
		if(NO == [self hasRippingTasks]) {
			[[_ripperController window] performClose:self];
		}
	}
}

- (void) spawnRipperThreads
{
	NSMutableArray *activeDrives = [NSMutableArray arrayWithCapacity:4];
	
	@synchronized(_rippingTasks) {
		
		
		if(0 != [_rippingTasks count] && NO == [[[_rippingTasks objectAtIndex:0] valueForKeyPath:@"ripper.started"] boolValue]) {
			[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_rippingTasks objectAtIndex:0] withObject:self];
		}
	}
}

- (void) ripDidStart:(RipperTask* ) task
{
	NSString *trackName = [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Rip started for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip started" description:trackName
						   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripDidStop:(RipperTask* ) task
{
	NSString *trackName = [task description];

	[LogController logMessage:[NSString stringWithFormat:@"Rip stopped for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip stopped" description:trackName
						   notificationName:@"Rip stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];
}

- (void) ripDidComplete:(RipperTask* ) task
{
	NSString		*trackName			= [task description];
		
	[LogController logMessage:[NSString stringWithFormat:@"Rip completed for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip completed" description:trackName
						   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];

	[self runEncodersForTask:task];
}

#pragma mark Converting Functionality

- (void) removeConvertingTask:(ConverterTask *) task
{
	// Remove from the list of converting tasks
	if([_convertingTasks containsObject:task]) {
		[task removeObserver:self forKeyPath:@"converter.started"];
		[task removeObserver:self forKeyPath:@"converter.completed"];
		[task removeObserver:self forKeyPath:@"converter.stopped"];
		
		[[self mutableArrayValueForKey:@"convertingTasks"] removeObject:task];
		
		// Hide the converter window if no more tasks
		if(NO == [self hasConvertingTasks]) {
			[[_converterController window] performClose:self];
		}
	}
}

- (void) spawnConverterThreads
{
	unsigned	i;
	unsigned	limit;
	unsigned	maxConverterThreads;
	
	@synchronized(_convertingTasks) {
		maxConverterThreads = (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumConverterThreads"];
		limit = (maxConverterThreads < [_convertingTasks count] ? maxConverterThreads : [_convertingTasks count]);
		
		// Start converting the next file(s)
		for(i = 0; i < limit; ++i) {
			if(NO == [[[_convertingTasks objectAtIndex:i] valueForKeyPath:@"converter.started"] boolValue]) {
				[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_convertingTasks objectAtIndex:i] withObject:self];
			}
		}	
	}
}

- (void) convertDidStart:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Convert started for %@", filename]];
	[GrowlApplicationBridge notifyWithTitle:@"Convert started" description:filename
						   notificationName:@"Convert started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) convertDidStop:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Convert stopped for %@", filename]];
	[GrowlApplicationBridge notifyWithTitle:@"Convert stopped" description:filename
						   notificationName:@"Convert stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeConvertingTask:task];
	[self spawnConverterThreads];
}

- (void) convertDidComplete:(ConverterTask* ) task
{
	NSString	*filename		= [task description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Convert completed for %@", filename]];
	[GrowlApplicationBridge notifyWithTitle:@"Convert completed" description:filename
						   notificationName:@"Convert completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	[self removeConvertingTask:task];
	[self spawnConverterThreads];
	
	[self runEncodersForTask:task];
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
				
				[encoderTask addObserver:self forKeyPath:@"encoder.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
				[encoderTask addObserver:self forKeyPath:@"encoder.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
				[encoderTask addObserver:self forKeyPath:@"encoder.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];
				
				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden]) {					
					[[_encoderController window] orderFront:self];
				}
				
				// Add the encoder to our list of encoding tasks
				[[self mutableArrayValueForKey:@"encodingTasks"] addObject:[encoderTask autorelease]];
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
				
				[encoderTask addObserver:self forKeyPath:@"encoder.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
				[encoderTask addObserver:self forKeyPath:@"encoder.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
				[encoderTask addObserver:self forKeyPath:@"encoder.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];
				
				// Show the encoder window if it is hidden
				if(NO == [[NSApplication sharedApplication] isHidden]) {					
					[[_encoderController window] orderFront:self];
				}
				
				// Add the encoder to our list of encoding tasks
				[[self mutableArrayValueForKey:@"encodingTasks"] addObject:[encoderTask autorelease]];
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

	[encoderTask addObserver:self forKeyPath:@"encoder.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
	[encoderTask addObserver:self forKeyPath:@"encoder.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
	[encoderTask addObserver:self forKeyPath:@"encoder.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];
	
	// Show the encoder window if it is hidden
	if(NO == [[NSApplication sharedApplication] isHidden]) {					
		[[_encoderController window] orderFront:self];
	}
	
	// Add the encoder to our list of encoding tasks
	[[self mutableArrayValueForKey:@"encodingTasks"] addObject:[encoderTask autorelease]];
	[self spawnEncoderThreads];			
	
}

- (void) removeEncodingTask:(EncoderTask *) task
{
	// Remove from the list of encoding tasks
	if([_encodingTasks containsObject:task]) {
		[task removeObserver:self forKeyPath:@"encoder.started"];
		[task removeObserver:self forKeyPath:@"encoder.completed"];
		[task removeObserver:self forKeyPath:@"encoder.stopped"];

		[[self mutableArrayValueForKey:@"encodingTasks"] removeObject:task];

		// Hide the encoder window if no more tasks
		if(NO == [self hasEncodingTasks]) {
			[[_encoderController window] performClose:self];
		}
	}	
}

- (void) spawnEncoderThreads
{
	unsigned	i;
	unsigned	limit;
	unsigned	maxEncoderThreads;
	
	@synchronized(_encodingTasks) {
		maxEncoderThreads = (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];
		limit = (maxEncoderThreads < [_encodingTasks count] ? maxEncoderThreads : [_encodingTasks count]);
		
		// Start encoding the next track(s)
		for(i = 0; i < limit; ++i) {
			if(NO == [[[_encodingTasks objectAtIndex:i] valueForKeyPath:@"encoder.started"] boolValue]) {
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
	[GrowlApplicationBridge notifyWithTitle:@"Encode started" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
						   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encodeDidStop:(EncoderTask* ) task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task getType];

	[LogController logMessage:[NSString stringWithFormat:@"Encode stopped for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode stopped" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
}

- (void) encodeDidComplete:(EncoderTask* ) task
{
	NSString	*trackName		= [task description];
	NSString	*type			= [task getType];
	
	[LogController logMessage:[NSString stringWithFormat:@"Encode completed for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode completed" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
}

@end
