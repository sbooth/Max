/*
 *  $Id: TaskMaster.m 205 2005-12-05 06:04:34Z me $
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
#import "MPEGEncoderTask.h"
#import "FLACEncoderTask.h"
#import "OggFLACEncoderTask.h"
#import "OggVorbisEncoderTask.h"
#import "CoreAudioEncoderTask.h"
#import "LibsndfileEncoderTask.h"
#import "MissingResourceException.h"
#import "IOException.h"
#import "UtilityFunctions.h"

#import <Growl/GrowlApplicationBridge.h>


static TaskMaster *sharedController = nil;

@interface TaskMaster (Private)
- (void) spawnEncoderThreads;
- (void) spawnRipperThreads;
- (void) removeRippingTask:(RipperTask *) task;
- (void) removeEncodingTask:(EncoderTask *) task;
- (void) runEncoder:(Class)encoderClass filename:(NSString *)filename source:(RipperTask *)task track:(Track *)track;
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
		
		_rippingTasks		= [[NSMutableArray arrayWithCapacity:20] retain];
		_encodingTasks		= [[NSMutableArray arrayWithCapacity:20] retain];

		_ripperController	= [[RipperController sharedController] retain];
		_encoderController	= [[EncoderController sharedController] retain];

		// Avoid infinite loops in init
		[_ripperController setValue:self forKey:@"taskMaster"];
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
	[_encoderController release];
	
	[_rippingTasks release];
	[_encodingTasks release];
	
	[super dealloc];
}

#pragma mark Task Management

- (BOOL)		hasTasks									{ return ([self hasRippingTasks] || [self hasEncodingTasks]); }
- (BOOL)		hasRippingTasks								{ return (0 != [_rippingTasks count]); }
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
	[self stopAllEncodingTasks:sender];
}

- (BOOL) compactDiscDocumentHasRippingTasks:(CompactDiscDocument *)document
{
	NSEnumerator	*enumerator		= [_rippingTasks objectEnumerator];
	RipperTask		*ripperTask;
	
	while((ripperTask = [enumerator nextObject])) {
		if([document isEqual:[[ripperTask getTrack] getCompactDiscDocument]]) {
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
		if([document isEqual:[[ripperTask getTrack] getCompactDiscDocument]]) {
			[ripperTask stop];
		}
	}
}

- (void) encodeTrack:(Track *)track outputBasename:(NSString *)basename
{
	RipperTask	*ripperTask		= nil;
	
	// Start rip
	ripperTask = [[RipperTask alloc] initWithTrack:track];
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

- (void) displayExceptionSheet:(NSException *) exception
{
//	displayExceptionSheet(exception, [self window], self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
}

- (void)alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(void *) contextInfo
{
	// Nothing for now
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
	if(0 != [_rippingTasks count] && NO == [[[_rippingTasks objectAtIndex:0] valueForKeyPath:@"ripper.started"] boolValue]) {
		[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_rippingTasks objectAtIndex:0] withObject:self];
	}
}

- (void) ripDidStart:(RipperTask* ) task
{
	NSString *trackName = [[task valueForKey:@"track"] description];
	
	[LogController logMessage:[NSString stringWithFormat:@"Rip started for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip started" description:trackName
						   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripDidStop:(RipperTask* ) task
{
	NSString *trackName = [[task valueForKey:@"track"] description];

	[LogController logMessage:[NSString stringWithFormat:@"Rip stopped for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip stopped" description:trackName
						   notificationName:@"Rip stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];
}

- (void) ripDidComplete:(RipperTask* ) task
{
	NSArray			*libsndfileFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"libsndfileOutputFormats"];
	NSArray			*coreAudioFormats	= [[NSUserDefaults standardUserDefaults] objectForKey:@"coreAudioOutputFormats"];
	Track			*track				= [task valueForKey:@"track"];
	NSString		*trackName			= [track description];
	NSString		*basename			= [task valueForKey:@"basename"];
	NSString		*filename			= nil;

		
	[LogController logMessage:[NSString stringWithFormat:@"Rip completed for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip completed" description:trackName
						   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];

	// Create encoder tasks for the rip that just completed
	@try {
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputMP3"]) {
			filename = generateUniqueFilename(basename, @"mp3");
			[self runEncoder:[MPEGEncoderTask class] filename:filename source:task track:track];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputFLAC"]) {
			filename = generateUniqueFilename(basename, @"flac");
			[self runEncoder:[FLACEncoderTask class] filename:filename source:task track:track];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggFLAC"]) {
			filename = generateUniqueFilename(basename, @"oggflac");
			[self runEncoder:[OggFLACEncoderTask class] filename:filename source:task track:track];
		}
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggVorbis"]) {
			filename = generateUniqueFilename(basename, @"ogg");
			[self runEncoder:[OggVorbisEncoderTask class] filename:filename source:task track:track];
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
				
				filename		= generateUniqueFilename(basename, extension);
				encoderTask		= [[CoreAudioEncoderTask alloc] initWithSource:task target:filename track:track formatInfo:formatInfo];
				
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
				filename = generateUniqueFilename(basename, [formatInfo valueForKey:@"extension"]);
				
				EncoderTask *encoderTask = [[LibsndfileEncoderTask alloc] initWithSource:task target:filename track:track formatInfo:formatInfo];
				
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

#pragma mark Encoding functionality

- (void) runEncoder:(Class)encoderClass filename:(NSString *)filename source:(RipperTask *)task track:(Track *)track
{
	// Create the encoder
	EncoderTask *encoderTask = [[encoderClass alloc] initWithSource:task target:filename track:track];
	
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
	
	maxEncoderThreads = (unsigned) [[NSUserDefaults standardUserDefaults] integerForKey:@"maximumEncoderThreads"];
	limit = (maxEncoderThreads < [_encodingTasks count] ? maxEncoderThreads : [_encodingTasks count]);
	
	// Start encoding the next track(s)
	for(i = 0; i < limit; ++i) {
		if(NO == [[[[_encodingTasks objectAtIndex:i] valueForKey:@"encoder"] valueForKey:@"started"] boolValue]) {
			[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_encodingTasks objectAtIndex:i] withObject:self];
		}
	}	
}

- (void) encodeDidStart:(EncoderTask* ) task
{
	NSString	*trackName		= [[task valueForKey:@"track"] description];
	NSString	*type			= [task getType];

	[LogController logMessage:[NSString stringWithFormat:@"Encode started for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode started" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
						   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encodeDidStop:(EncoderTask* ) task
{
	NSString	*trackName		= [[task valueForKey:@"track"] description];
	NSString	*type			= [task getType];

	[LogController logMessage:[NSString stringWithFormat:@"Encode stopped for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode stopped" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
}

- (void) encodeDidComplete:(EncoderTask* ) task
{
	NSString	*trackName		= [[task valueForKey:@"track"] description];
	NSString	*type			= [task getType];
	
	[LogController logMessage:[NSString stringWithFormat:@"Encode completed for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode completed" description:[NSString stringWithFormat:@"%@\nFile format: %@", trackName, type]
						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
}

@end
