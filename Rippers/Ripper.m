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

#import "Ripper.h"
#import "RipperTask.h"
#import "SectorRange.h"

@implementation Ripper

+ (void) connectWithPorts:(NSArray *)portArray
{
	NSAutoreleasePool	*pool				= nil;
	NSConnection		*connection			= nil;
	Ripper				*ripper				= nil;
	RipperTask			*owner				= nil;
	
	@try {
		pool			= [[NSAutoreleasePool alloc] init];
		connection		= [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0] sendPort:[portArray objectAtIndex:1]];
		owner			= (RipperTask *)[connection rootProxy];
		ripper			= [[self alloc] initWithSectors:[owner sectors] deviceName:[owner deviceName]];
		
		// Setup ripper logging
		[ripper setLogActivity:[[NSUserDefaults standardUserDefaults] boolForKey:@"enableRipperLogging"]];
			
		[ripper setDelegate:owner];
		[owner ripperReady:ripper];
	}	
	
	@catch(NSException *exception) {
		if(nil != owner) {
			[owner setException:exception];
			[owner setStopped:YES];
		}
	}
	
	@finally {
		[ripper release];
		[pool release];
	}
}

- (id) initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName
{
	if((self = [super init])) {
		
		_sectors		= [sectors retain];
		_deviceName		= [deviceName retain];
		_logActivity	= NO;
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_sectors release];			_sectors = nil;
	[_deviceName release];		_deviceName = nil;
	
	[super dealloc];
}

- (BOOL)				logActivity									{ return _logActivity; }
- (void)				setLogActivity:(BOOL)logActivity			{ _logActivity = logActivity; }

- (NSString *)			deviceName									{ return [[_deviceName retain] autorelease]; }

- (void)					setDelegate:(id <RipperTaskMethods>)delegate	{ _delegate = delegate; }
- (id <RipperTaskMethods>)	delegate										{ return _delegate; }

- (oneway void) ripToFile:(NSString *)filename
{}

@end
