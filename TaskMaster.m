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
#import "MPEGEncoderTask.h"
#import "FLACEncoderTask.h"
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
	if((self = [super initWithWindowNibName:@"Tasks"])) {
		_rippingTasks	= [[NSMutableArray alloc] initWithCapacity:20];
		_encodingTasks	= [[NSMutableArray alloc] initWithCapacity:20];

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

- (id) copyWithZone:(NSZone *)zone								{ return self; }
- (id) retain													{ return self; }
- (unsigned) retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (void) release												{ /* do nothing */ }
- (id) autorelease												{ return self; }

- (void) dealloc
{
	[_rippingTasks release];
	[_encodingTasks release];
	[super dealloc];
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"TaskMaster"];	
}

- (BOOL) hasActiveTasks
{
	return (0 != [_rippingTasks count] || 0 != [_encodingTasks count]);
}

- (void) removeAllTasks
{
	NSEnumerator	*enumerator;
	RipperTask		*ripperTask;
	EncoderTask		*encoderTask;
	
	enumerator = [_rippingTasks objectEnumerator];
	while((ripperTask = [enumerator nextObject])) {
		[self removeRippingTask:ripperTask];
	}

	enumerator = [_encodingTasks objectEnumerator];
	while((encoderTask = [enumerator nextObject])) {
		[self removeEncodingTask:encoderTask];
	}
}

- (void) encodeTrack:(Track *)track outputBasename:(NSString *)basename
{
	RipperTask	*ripperTask		= nil;
	
	// Show the tasks window if it is hidden
	[[self window] orderFront:self];

	// Start rip
	ripperTask = [[RipperTask alloc] initWithTrack:track];
	[ripperTask setValue:basename forKey:@"basename"];
	[ripperTask addObserver:self forKeyPath:@"ripper.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:ripperTask];	
	[ripperTask addObserver:self forKeyPath:@"ripper.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:ripperTask];	
	[ripperTask addObserver:self forKeyPath:@"ripper.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:ripperTask];	
		
	// Add the ripper to our list of ripping tasks
	[[self mutableArrayValueForKey:@"rippingTasks"] addObject:[ripperTask autorelease]];
	[_ripperStatusTextField setStringValue:[NSString stringWithFormat:@"Ripper Tasks: %u", [_rippingTasks count]]];
	[_ripperStatusTextField setHidden:NO];
	[self spawnRipperThreads];
}

- (void) displayExceptionSheet:(NSException *) exception
{
	displayExceptionSheet(exception, [self window], self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
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
		[self performSelectorOnMainThread:@selector(encodeDidComplete:) withObject:context waitUntilDone:TRUE];
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

		if(0 == [_rippingTasks count]) {
			[_ripperStatusTextField setHidden:YES];
		}
		else {
			[_ripperStatusTextField setStringValue:[NSString stringWithFormat:@"Ripper Tasks: %u", [_rippingTasks count]]];
			[_ripperStatusTextField setHidden:NO];
		}
	}
}

- (void) spawnRipperThreads
{
	if(0 != [_rippingTasks count] && NO == [[[[_rippingTasks objectAtIndex:0] valueForKey:@"ripper"] valueForKey:@"started"] boolValue]) {
		[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_rippingTasks objectAtIndex:0] withObject:self];
	}
}

- (void) ripDidStart:(RipperTask* ) task
{
	NSString *trackName = [[task valueForKey:@"track"] description];
	
	[[LogController sharedController] logMessage:[NSString stringWithFormat:@"Rip started for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip started" description:trackName
						   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripDidStop:(RipperTask* ) task
{
	NSString *trackName = [[task valueForKey:@"track"] description];

	[[LogController sharedController] logMessage:[NSString stringWithFormat:@"Rip stopped for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip stopped" description:trackName
						   notificationName:@"Rip stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];
}

- (void) ripDidComplete:(RipperTask* ) task
{
	Track			*track			= [task valueForKey:@"track"];
	NSString		*trackName		= [track description];
	NSString		*basename		= [task valueForKey:@"basename"];
	NSString		*filename		= nil;
	EncoderTask		*encoderTask	= nil;
	int				alertResult		= 0;
	BOOL			createFile		= YES;

	[[LogController sharedController] logMessage:[NSString stringWithFormat:@"Rip completed for %@", trackName]];
	[GrowlApplicationBridge notifyWithTitle:@"Rip completed" description:trackName
						   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[self removeRippingTask:task];
	[self spawnRipperThreads];

	// Create encoder tasks for the rip that just completed
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputMP3"]) {

		createFile	= YES;
		filename	= [basename stringByAppendingString:@".mp3"];

		// Check if the output file exists
		if([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:@"Yes"];
			[alert addButtonWithTitle:@"No"];
			[alert addButtonWithTitle:@"Save As…"];
			[alert setMessageText:@"Overwrite existing file?"];
			[alert setInformativeText:[NSString stringWithFormat:@"The file '%@' already exists.  Do you wish to replace it?", filename]];
			[alert setAlertStyle:NSCriticalAlertStyle];
			
			alertResult = [alert runModal];
			
			if(NSAlertFirstButtonReturn == alertResult) {
				// Remove the file
				if(-1 == unlink([filename UTF8String])) {
					@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
				}
			}
			else if(NSAlertSecondButtonReturn == alertResult) {
				createFile = NO;
			}
			else if(NSAlertThirdButtonReturn == alertResult) {
				NSSavePanel *panel = [NSSavePanel savePanel];
				[panel setRequiredFileType:@"mp3"];
				if(NSFileHandlingPanelOKButton == [panel runModal]) {
					filename = [panel filename];
					// Remove the file if it exists
					if([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
						if(-1 == unlink([filename UTF8String])) {
							@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
						}
					}
				}
			}
		}
		
		// Encode the file
		if(createFile) {
			encoderTask = [[MPEGEncoderTask alloc] initWithSource:task target:filename track:track];
			[encoderTask addObserver:self forKeyPath:@"encoder.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
			[encoderTask addObserver:self forKeyPath:@"encoder.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
			[encoderTask addObserver:self forKeyPath:@"encoder.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];
			
			// Add the encoder to our list of encoding tasks
			[[self mutableArrayValueForKey:@"encodingTasks"] addObject:[encoderTask autorelease]];
			[_encoderStatusTextField setStringValue:[NSString stringWithFormat:@"Encoder Tasks: %u", [_encodingTasks count]]];
			[_encoderStatusTextField setHidden:NO];
			[self spawnEncoderThreads];			
		}
	}
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputFLAC"]) {
		createFile	= YES;
		filename	= [basename stringByAppendingString:@".flac"];
		
		// Check if the output file exists
		if([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:@"Yes"];
			[alert addButtonWithTitle:@"No"];
			[alert addButtonWithTitle:@"Save As…"];
			[alert setMessageText:@"Overwrite existing file?"];
			[alert setInformativeText:[NSString stringWithFormat:@"The file '%@' already exists.  Do you wish to replace it?", filename]];
			[alert setAlertStyle:NSCriticalAlertStyle];
			
			alertResult = [alert runModal];
			
			if(NSAlertFirstButtonReturn == alertResult) {
				// Remove the file
				if(-1 == unlink([filename UTF8String])) {
					@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
				}
			}
			else if(NSAlertSecondButtonReturn == alertResult) {
				createFile = NO;
			}
			else if(NSAlertThirdButtonReturn == alertResult) {
				NSSavePanel *panel = [NSSavePanel savePanel];
				[panel setRequiredFileType:@"flac"];
				if(NSFileHandlingPanelOKButton == [panel runModal]) {
					filename = [panel filename];
					// Remove the file if it exists
					if([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
						if(-1 == unlink([filename UTF8String])) {
							@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
						}
					}
				}
			}
		}
		
		// Encode the file
		if(createFile) {
			encoderTask = [[FLACEncoderTask alloc] initWithSource:task target:filename track:track];
			[encoderTask addObserver:self forKeyPath:@"encoder.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
			[encoderTask addObserver:self forKeyPath:@"encoder.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];	
			[encoderTask addObserver:self forKeyPath:@"encoder.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:encoderTask];
			
			// Add the encoder to our list of encoding tasks
			[[self mutableArrayValueForKey:@"encodingTasks"] addObject:[encoderTask autorelease]];
			[_encoderStatusTextField setStringValue:[NSString stringWithFormat:@"Encoder Tasks: %u", [_encodingTasks count]]];
			[_encoderStatusTextField setHidden:NO];
			[self spawnEncoderThreads];			
		}
	}
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"outputOgg"]) {
		//	EncoderTask *oggEncoderTask = [[OggEncoderTask alloc] initWithSource:[_ripperTask valueForKey:@"path"] target:_basename trackName:_trackName];
		//	[_encoderTasks addObject:oggEncoderTask];
	}
}

#pragma mark Encoding functionality

- (void) removeEncodingTask:(EncoderTask *) task
{
	// Remove from the list of encoding tasks
	if([_encodingTasks containsObject:task]) {
		[task removeObserver:self forKeyPath:@"encoder.started"];
		[task removeObserver:self forKeyPath:@"encoder.completed"];
		[task removeObserver:self forKeyPath:@"encoder.stopped"];

		[[self mutableArrayValueForKey:@"encodingTasks"] removeObject:task];

		if(0 == [_encodingTasks count]) {
			[_encoderStatusTextField setHidden:YES];
		}
		else {
			[_encoderStatusTextField setStringValue:[NSString stringWithFormat:@"Encoder Tasks: %u", [_encodingTasks count]]];
			[_encoderStatusTextField setHidden:NO];
		}
	}	

	// Close the tasks window if this is the last task
	if(NO == [self hasActiveTasks]) {
		NSWindow *tasksWindow = [self window];
		if([tasksWindow isVisible]) {
			[tasksWindow performClose:self];
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

	[[LogController sharedController] logMessage:[NSString stringWithFormat:@"Encode started for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode started" description:[NSString stringWithFormat:@"%@ [%@]", trackName, type]
						   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encodeDidStop:(EncoderTask* ) task
{
	NSString	*trackName		= [[task valueForKey:@"track"] description];
	NSString	*type			= [task getType];

	[[LogController sharedController] logMessage:[NSString stringWithFormat:@"Encode stopped for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode stopped" description:[NSString stringWithFormat:@"%@ [%@]", trackName, type]
						   notificationName:@"Encode stopped" iconData:nil priority:0 isSticky:NO clickContext:nil];

	[task removeOutputFile];
	
	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
}

- (void) encodeDidComplete:(EncoderTask* ) task
{
	NSString	*trackName		= [[task valueForKey:@"track"] description];
	NSString	*type			= [task getType];
	Track		*track			= [task valueForKey:@"track"];
	
	[[LogController sharedController] logMessage:[NSString stringWithFormat:@"Encode completed for %@ [%@]", trackName, type]];
	[GrowlApplicationBridge notifyWithTitle:@"Encode completed" description:[NSString stringWithFormat:@"%@ [%@]", trackName, type]
						   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	

	[self removeEncodingTask:task];
	[self spawnEncoderThreads];
	
	[track setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
}

@end
