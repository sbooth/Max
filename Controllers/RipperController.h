/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import <Cocoa/Cocoa.h>

#import "RipperTask.h"

// Tag values for NSPopupButton
enum {
	kBasicRipper			= 0,
	kComparisonRipper		= 1,
	kParanoiaRipper			= 2
//	kSecureRipper			= 3
};

@interface RipperController : NSWindowController
{
	IBOutlet NSTableView		*_taskTable;
	IBOutlet NSArrayController	*_tasksController;
	
	NSMutableArray				*_tasks;
	BOOL						_freeze;
}

+ (RipperController *)	sharedController;

// Functionality
- (void)			ripTracks:(NSArray *)tracks settings:(NSDictionary *)settings;

- (BOOL)			documentHasRipperTasks:(CompactDiscDocument *)document;
- (void)			stopRipperTasksForDocument:(CompactDiscDocument *)document;

- (BOOL)			hasTasks;
- (NSUInteger)		countOfTasks;

// Action methods
- (IBAction)		stopSelectedTasks:(id)sender;
- (IBAction)		stopAllTasks:(id)sender;

// Callbacks
- (void)			ripperTaskDidStart:(RipperTask *)task;
- (void)			ripperTaskDidStop:(RipperTask *)task;
- (void)			ripperTaskDidComplete:(RipperTask *)task;

@end
