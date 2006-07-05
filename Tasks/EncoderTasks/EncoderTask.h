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

#import <Cocoa/Cocoa.h>

#import "Encoder.h"
#import "Track.h"
#import "Task.h"
#import "AudioMetadata.h"
#import "PCMGeneratingTask.h"

@interface EncoderTask : Task
{
	NSConnection			*_connection;
	NSString				*_outputDirectory;
	NSString				*_outputFilename;
	Class					_encoderClass;
	id <EncoderMethods>		_encoder;
	NSArray					*_tracks;
	PCMGeneratingTask		*_task;
	BOOL					_writeSettingsToComment;
}

- (id)				initWithTask:(PCMGeneratingTask *)task;

- (unsigned)		countOfTracks;
- (Track *)			objectInTracksAtIndex:(unsigned)index;

//- (void) insertObject:(Track *)track inTracksAtIndex:(unsigned)index;
//- (void) removeObjectFromTracksAtIndex:(unsigned)index;

- (void)			setTracks:(NSArray *)tracks;
//- (NSArray *)		tracks;

- (void)			run;
- (void)			stop;

- (NSString *)		outputDirectory;
- (void)			setOutputDirectory:(NSString *)outputDirectory;

- (NSString *)		extension;

- (NSString *)		inputFilename;
- (NSString *)		outputFilename;

- (NSString *)		outputFormat;

- (void)			removeOutputFile;

- (AudioMetadata *) metadata;

- (void)			writeTags;

- (NSString *)		settings;

- (void)			encoderReady:(id)anObject;

- (BOOL)			formatLegalForCueSheet;
- (NSString *)		cueSheetFormatName;
- (void)			generateCueSheet;

@end
