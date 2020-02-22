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

@class AudioMetadata, CompactDiscDocument, EncoderTask;

// List of the encoder components available in Max
enum {
	kComponentCoreAudio			= 0,
	kComponentLibsndfile		= 1,
	
	kComponentFLAC				= 2,
	kComponentOggFLAC			= 3,
	kComponentWavPack			= 4,
	kComponentMonkeysAudio		= 5,
	kComponentOggVorbis			= 6,
	kComponentMP3				= 7,
	kComponentOggSpeex			= 8
};

@interface EncoderController : NSWindowController
{
	IBOutlet NSTableView		*_taskTable;
	IBOutlet NSArrayController	*_tasksController;
	
	NSMutableArray				*_tasks;
	BOOL						_freeze;
}

+ (EncoderController *)	sharedController;

// Functionality
- (void)			encodeFile:(NSString *)filename metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings;
- (void)			encodeFile:(NSString *)filename metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings inputTracks:(NSArray *)inputTracks;

- (void)			encodeFiles:(NSArray *)filenames metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings;
- (void)			encodeFiles:(NSArray *)filenames metadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings inputTracks:(NSArray *)inputTracks;

- (BOOL)			documentHasEncoderTasks:(CompactDiscDocument *)document;
- (void)			stopEncoderTasksForDocument:(CompactDiscDocument *)document;

- (BOOL)			hasTasks;
- (NSUInteger)		countOfTasks;

// Action methods
- (IBAction)		stopSelectedTasks:(id)sender;
- (IBAction)		stopAllTasks:(id)sender;

// Callbacks
- (void)			encoderTaskDidStart:(EncoderTask *)task;
- (void)			encoderTaskDidStop:(EncoderTask *)task;
- (void)			encoderTaskDidComplete:(EncoderTask *)task;

- (void)			encoderTaskDidStart:(EncoderTask *)task notify:(BOOL)notify;
- (void)			encoderTaskDidStop:(EncoderTask *)task notify:(BOOL)notify;
- (void)			encoderTaskDidComplete:(EncoderTask *)task notify:(BOOL)notify;

@end
