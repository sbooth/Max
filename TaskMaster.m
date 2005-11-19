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
#import "RipperTask.h"
#import "EncoderTask.h"
#import "Tagger.h"
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
	if(self = [super initWithWindowNibName:@"Tasks"]) {
		_taskList		= [[NSMutableArray alloc] initWithCapacity:20];
		_rippingTasks	= [[NSMutableArray alloc] initWithCapacity:20];
		_encodingTasks	= [[NSMutableArray alloc] initWithCapacity:20];

		[self setShouldCascadeWindows:NO];
		[self setWindowFrameAutosaveName:@"TaskMaster"];	
	}
	return self;
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

- (void) runTask:(Task *) task
{
	// If this task isn't in our task list, add it to the list and begin ripping
	if(NO == [_taskList containsObject:task]) {
		
		// Add the task to our master list of pending/active tasks
		@synchronized(_taskList) {
			[_taskList addObject:task];
		}
		
		// Add the ripping portion of the task to our list of ripping tasks
		@synchronized(_rippingTasks) {
			[[self mutableArrayValueForKey:@"rippingTasks"] addObject:[task valueForKey:@"ripperTask"]];				
			[self spawnRipperThreads];
		}			
	}
	
	// We already know about this task, determine the next step
	else {
		@synchronized(_taskList) {
			// If encoding is complete, tag the file
			if(YES == [[[task valueForKey:@"encoderTask"] valueForKey:@"completed"] boolValue]) {
				[Tagger tagFile:[task valueForKey:@"filename"] fromTrack:[task valueForKey:@"track"]];
				
				// Uncheck the selection
				[[task valueForKey:@"track"] setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
				
				// Remove the ripper temporary 
				[[task valueForKey:@"ripperTask"] removeTemporaryFile];
				[self removeTask:task];
			}
			// Add the encoding portion of the task to our list and run it
			else {
				[[self mutableArrayValueForKey:@"encodingTasks"] addObject:[task valueForKey:@"encoderTask"]];
				[self spawnEncoderThreads];
			}
		}
	}		
}

- (void) removeTask:(Task *) task
{
	[self removeRippingTask:[task valueForKey:@"ripperTask"]];
	
	@synchronized(_encodingTasks) {
		if(YES == [_encodingTasks containsObject:[task valueForKey:@"encoderTask"]]) {
			[[self mutableArrayValueForKey:@"encodingTasks"] removeObject:[task valueForKey:@"encoderTask"]];
		}
	}
	
	@synchronized(_taskList) {
		[_taskList removeObject:task];
		
		// Close the tasks window if this is the last task
		if(0 == [_taskList count]) {
			NSWindow *tasksWindow = [[TaskMaster sharedController] window];
			if([tasksWindow isVisible]) {
				[tasksWindow performClose:self];
			}
		}
	}
}

- (void) displayExceptionSheet:(NSException *) exception
{
	displayExceptionSheet(exception, [self window], self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
}

- (void)alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(void *) contextInfo
{
	// Nothing for now
}

#pragma mark Rip functionality

- (void) removeRippingTask:(RipperTask *) task
{
	// Remove from the list of ripping tasks
	@synchronized(_rippingTasks) {
		if(YES == [_rippingTasks containsObject:task]) {
			NSLog(@"TaskMaster::removeRippingTask(%@)", [task valueForKey:@"trackName"]);
			[[self mutableArrayValueForKey:@"rippingTasks"] removeObject:task];
		}
	}	
}

- (void) spawnRipperThreads
{
	@synchronized(_rippingTasks) {
		if(0 != [_rippingTasks count] && NO == [[[[_rippingTasks objectAtIndex:0] valueForKey:@"ripper"] valueForKey:@"started"] boolValue]) {
			[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_rippingTasks objectAtIndex:0] withObject:self];
		}
	}
}

- (void) ripDidStart:(id) object
{
	[GrowlApplicationBridge notifyWithTitle:@"Rip started" description:[object valueForKey:@"trackName"]
	   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) ripDidStop:(id) object
{
	// Remove from the list of ripping tasks
	[self removeRippingTask:object];
	
	[GrowlApplicationBridge notifyWithTitle:@"Rip stopped" description:[object valueForKey:@"trackName"]
	   notificationName:@"Rip started" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	// Start ripping the next track
	[self spawnRipperThreads];
}

- (void) ripDidComplete:(id) object
{
	// Remove from the list of ripping tasks
	[self removeRippingTask:object];
	
	[GrowlApplicationBridge notifyWithTitle:@"Rip completed" description:[object valueForKey:@"trackName"]
	   notificationName:@"Rip completed" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	// Start ripping the next track
	[self spawnRipperThreads];
}

#pragma mark Encoding functionality

- (void) removeEncodingTask:(EncoderTask *) task
{
	// Remove from the list of encoding tasks
	@synchronized(_encodingTasks) {
		[[self mutableArrayValueForKey:@"encodingTasks"] removeObject:task];
	}	
}

- (void) spawnEncoderThreads
{
	int i;
	int limit;
	
	@synchronized(_encodingTasks) {
		limit = ([[NSUserDefaults standardUserDefaults] integerForKey:@"org.sbooth.Max.maximumEncoderThreads"] < [_encodingTasks count] ? [[NSUserDefaults standardUserDefaults] integerForKey:@"org.sbooth.Max.maximumEncoderThreads"] : [_encodingTasks count]);
		
		// Start encoding the next track(s)
		for(i = 0; i < limit; ++i) {
			if(NO == [[[[_encodingTasks objectAtIndex:i] valueForKey:@"encoder"] valueForKey:@"started"] boolValue]) {
				[NSThread detachNewThreadSelector:@selector(run:) toTarget:[_encodingTasks objectAtIndex:i] withObject:self];
			}
		}	
	}
}

- (void) encodeDidStart:(id) object
{
	[GrowlApplicationBridge notifyWithTitle:@"Encode started" description:[object valueForKey:@"trackName"]
	   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
}

- (void) encodeDidStop:(id) object
{
	// Remove from the list of encoding tasks
	[self removeEncodingTask:object];
	
	[GrowlApplicationBridge notifyWithTitle:@"Encode stopped" description:[object valueForKey:@"trackName"]
	   notificationName:@"Encode started" iconData:nil priority:0 isSticky:NO clickContext:nil];
	
	// Start encoding the next files if less than the specified number of threads are running
	[self spawnEncoderThreads];
}

- (void) encodeDidComplete:(id) object
{
	// Remove from the list of encoding tasks
	[self removeEncodingTask:object];
	
	[GrowlApplicationBridge notifyWithTitle:@"Encode completed" description:[object valueForKey:@"trackName"]
	   notificationName:@"Encode completed" iconData:nil priority:0 isSticky:NO clickContext:nil];

	// Start encoding the next files if less than the specified number of threads are running
	[self spawnEncoderThreads];
}

@end
