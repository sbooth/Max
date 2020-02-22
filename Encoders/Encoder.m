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
		encoder			= [[self alloc] init];
				
		[encoder setDelegate:owner];
		[owner encoderReady:encoder];		
	}	
	
	@catch(NSException *exception) {
		[owner setException:exception];
		[owner setStopped:YES];
	}
	
	@finally {
		[encoder release];
		[pool release];
	}
}

- (id <EncoderTaskMethods>)	delegate									{ return _delegate; }
- (void)				setDelegate:(id <EncoderTaskMethods>)delegate	{ _delegate = delegate; }

- (oneway void)			encodeToFile:(NSString *)filename				{}

- (NSString *)			settingsString									{ return nil; }

@end
