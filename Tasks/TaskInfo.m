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

#import "TaskInfo.h"

@implementation TaskInfo

+ (TaskInfo *) taskInfoWithSettings:(NSDictionary *)settings metadata:(AudioMetadata *)metadata
{
	TaskInfo	*result		= nil;
	
	NSParameterAssert(nil != settings);
	NSParameterAssert(nil != metadata);
	
	result		= [[TaskInfo alloc] init];
	
	[result setSettings:settings];
	[result setMetadata:metadata];

	return [result autorelease];
}

- copyWithZone:(NSZone *)zone
{
    TaskInfo	*copy		= [[TaskInfo allocWithZone:zone] init];
	
	copy->_settings			= [_settings retain];
	copy->_metadata			= [_metadata retain];
	copy->_inputFilenames	= [_inputFilenames retain];
	copy->_inputTracks		= [_inputTracks retain];
	
    return copy;
}

- (void) dealloc
{
	[_settings release];		_settings = nil;
	[_metadata release];		_metadata = nil;
	[_inputFilenames release];	_inputFilenames = nil;
	[_inputTracks release];		_inputTracks = nil;
	
	[super dealloc];
}

#pragma mark Settings and Metadata

- (NSDictionary *)			settings									{ return [[_settings retain] autorelease]; }
- (void)					setSettings:(NSDictionary *)settings		{ [_settings release]; _settings = [settings retain]; }

- (AudioMetadata *)			metadata									{ return [[_metadata retain] autorelease]; }
- (void)					setMetadata:(AudioMetadata *)metadata		{ [_metadata release]; _metadata = [metadata retain]; }

#pragma mark Input

- (NSArray *)				inputFilenames								{ return [[_inputFilenames retain] autorelease]; }
- (void)					setInputFilenames:(NSArray *)inputFilenames	{ [_inputFilenames release]; _inputFilenames = [inputFilenames retain]; [self setInputFileIndex:0]; }

- (NSArray *)				inputTracks									{ return [[_inputTracks retain] autorelease]; }
- (void)					setInputTracks:(NSArray *)inputTracks		{ [_inputTracks release]; _inputTracks = [inputTracks retain]; }

- (unsigned)				inputFileIndex								{ return _inputFileIndex; }
- (void)					setInputFileIndex:(unsigned)inputFileIndex	{ _inputFileIndex = inputFileIndex; }

- (void)					incrementInputFileIndex						{ ++_inputFileIndex; }

- (NSString *)				inputFilenameAtInputFileIndex				{ return [[self inputFilenames] objectAtIndex:[self inputFileIndex]]; }

@end
