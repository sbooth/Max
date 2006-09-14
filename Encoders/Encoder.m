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

#import "Encoder.h"
#import "EncoderTask.h"

@implementation Encoder

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool	*pool				= nil;
	NSConnection		*connection			= nil;
	Encoder				*encoder			= nil;
	EncoderTask			*owner				= nil;
	
	@try {
		pool			= [[NSAutoreleasePool alloc] init];
		connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
		owner			= (EncoderTask *)[connection rootProxy];
		encoder			= [[self alloc] initWithFilename:[[[owner taskInfo] inputFilenames] objectAtIndex:0]];
		
		[encoder setDelegate:owner];
		[owner encoderReady:encoder];
		
		[encoder release];
	}	
	
	@catch(NSException *exception) {
		[owner setException:exception];
		[owner setStopped:YES];
	}
	
	@finally {
		[pool release];
	}
}

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super init])) {

		_source = [[AudioSource audioSourceForFilename:filename] retain];
		NSAssert(nil != _source, @"Unable to create the AudioSource");

		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_source release];	_source = nil;
	
	[super dealloc];
}

- (AudioSource *)		source											{ return [[_source retain] autorelease]; }

- (id <EncoderTaskMethods>)	delegate									{ return _delegate; }
- (void)				setDelegate:(id <EncoderTaskMethods>)delegate	{ _delegate = delegate; }

- (oneway void)			encodeToFile:(NSString *)filename				{}

- (NSString *)			settings										{ return nil; }

@end
