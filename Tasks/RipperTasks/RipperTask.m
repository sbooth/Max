/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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

#import "RipperTask.h"
#import "RipperMethods.h"
#import "RipperController.h"
#import "SectorRange.h"
#import "CompactDiscDocument.h"
#import "UtilityFunctions.h"
#import "StopException.h"

@interface RipperTask (Private)
- (void)	touchOutputFile;
@end

@implementation RipperTask

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (id) initWithTracks:(NSArray *)tracks
{
	Track				*track;
	
	NSParameterAssert(nil != tracks);
	NSParameterAssert(0 != [tracks count]);
	
	if((self = [super init])) {
		
		_connection		= nil;
		
		_tracks			= [tracks retain];
		_deviceName		= [[[[_tracks objectAtIndex:0] document] disc] deviceName];
		_sectors		= [[NSMutableArray alloc] initWithCapacity:[tracks count]];
		
		for(track in _tracks) {
			
			// Don't try to rip data tracks
			if([track dataTrack]) {
				continue;
			}
			
			[track setRipInProgress:YES];
			[_sectors addObject:[SectorRange sectorRangeWithFirstSector:[track firstSector] lastSector:[track lastSector]]];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_connection release];
	_connection = nil;
	[_sectors release];
	_sectors = nil;
	[_tracks release];
	_tracks = nil;
	[_phase release];
	_phase = nil;
	
	[super dealloc];
}

- (NSArray *)			sectors									{ return [[_sectors retain] autorelease]; }
- (NSString *)			deviceName								{ return [[_deviceName retain] autorelease]; }
- (NSUInteger)			countOfTracks							{ return [_tracks count]; }
- (Track *)				objectInTracksAtIndex:(unsigned)index	{ return [_tracks objectAtIndex:index]; }

- (NSString *)			phase									{ return [[_phase retain] autorelease]; }
- (void)				setPhase:(NSString *)phase				{ [_phase release]; _phase = [phase retain]; }

- (void) run
{
	NSPort			*port1			= [NSPort port];
	NSPort			*port2			= [NSPort port];
	NSArray			*portArray		= nil;
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted:YES];
	
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_ripperClass withObject:portArray];
}

- (void) ripperReady:(id)anObject
{
    [anObject setProtocolForProxy:@protocol(RipperMethods)];
	[self setOutputFilename:GenerateTemporaryFilename([[[self taskInfo] settings] objectForKey:@"temporaryDirectory"], @"caf")];
	[self touchOutputFile];
	[anObject ripToFile:[self outputFilename]];
}

- (void) setStarted:(BOOL)started
{
	[super setStarted:started];
	[[RipperController sharedController] ripperTaskDidStart:self]; 
}

- (void) setStopped :(BOOL)stopped
{
	Track				*track;
	
	[super setStopped:stopped];
	
	// Once we're stopped, invalidate the connection
	[_connection invalidate];

	for(track in _tracks) {
		[track setRipInProgress:NO];
	}
	
	[self setShouldDeleteOutputFile:YES];
	
	[[RipperController sharedController] ripperTaskDidStop:self]; 
}

- (void) setCompleted:(BOOL)completed
{
	Track				*track;

	[super setCompleted:completed];
	
	// Once we're complete, invalidate the connection
	[_connection invalidate];

	for(track in _tracks) {
		[track setRipInProgress:NO];
	}
	
	[[RipperController sharedController] ripperTaskDidComplete:self];
}

- (void) stop
{
	if([self started] && NO == [self stopped]) {
		[self setShouldStop:YES];
	}
	else {
		[self setStopped:YES];
	}
}

- (void) setException:(NSException *)exception
{
	NSAlert		*alert		= nil;
	
	[super setException:exception];
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while ripping tracks from the disc \"%@\".", @"Exceptions", @""), [[[self objectInTracksAtIndex:0] document] title]]];
	[alert setInformativeText:[[self exception] reason]];
	[alert setAlertStyle:NSWarningAlertStyle];		
	[alert runModal];
}

- (void) generateCueSheet
{}

- (NSString *)		description
{
	NSString		*result		= nil;
	
	result =  [[[self taskInfo] metadata] description];
	
	return (nil == result ? @"unk" : result);
}

@end

@implementation RipperTask (Private)

- (void) touchOutputFile
{
	NSNumber		*permissions	= [NSNumber numberWithUnsignedLong:S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH];
	NSDictionary	*attributes		= [NSDictionary dictionaryWithObject:permissions forKey:NSFilePosixPermissions];	
	BOOL			result			= [[NSFileManager defaultManager] createFileAtPath:[self outputFilename] contents:nil attributes:attributes];
	NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));	
}

@end
