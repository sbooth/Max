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

#import "Converter.h"

#import "ConverterTask.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"

#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

@implementation Converter

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool	*pool;
	NSConnection		*connection;
	Converter			*converter;
	ConverterTask		*owner;
	
	pool			= [[NSAutoreleasePool alloc] init];
	connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
	owner			= (ConverterTask *)[connection rootProxy];
	converter		= [[self alloc] initWithInputFilename:[owner getInputFilename]];
	
	[converter setDelegate:owner];
	[owner converterReady:converter];
	
	[converter release];
	
	[[NSRunLoop currentRunLoop] run];
	
	[pool release];
}

- (id) initWithInputFilename:(NSString *)inputFilename
{
	if((self = [super init])) {
		_inputFilename = [inputFilename retain];		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_inputFilename release];
	
	[super dealloc];
}

- (void)				setDelegate:(id <TaskMethods>)delegate		{ _delegate = delegate; }
- (id <TaskMethods>)	delegate									{ return _delegate; }

- (oneway void)			convertToFile:(int)file						{}

- (NSString *)			description									{ return [_inputFilename lastPathComponent]; }

@end
