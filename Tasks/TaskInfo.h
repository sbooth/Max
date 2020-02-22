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
#import "AudioMetadata.h"

@interface TaskInfo : NSObject <NSCopying>
{
	NSDictionary		*_settings;				// Settings applicable to the entire task
	AudioMetadata		*_metadata;				// Metadata for the task
	
	NSArray				*_inputFilenames;		// Input filename(s) for the task
	NSArray				*_inputTracks;			// For rips, the Track(s) that were ripped
	
	unsigned			_inputFileIndex;
}

+ (TaskInfo *)				taskInfoWithSettings:(NSDictionary *)settings metadata:(AudioMetadata *)metadata;

- (NSDictionary *)			settings;
- (void)					setSettings:(NSDictionary *)settings;

- (AudioMetadata *)			metadata;
- (void)					setMetadata:(AudioMetadata *)metadata;

- (NSArray *)				inputFilenames;
- (void)					setInputFilenames:(NSArray *)inputFilenames;

- (NSArray *)				inputTracks;
- (void)					setInputTracks:(NSArray *)inputTracks;

- (unsigned)				inputFileIndex;
- (void)					setInputFileIndex:(unsigned)inputFileIndex;
- (void)					incrementInputFileIndex;

- (NSString *)				inputFilenameAtInputFileIndex;

@end
