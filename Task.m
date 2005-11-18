/*
 *  $Id: CompactDiscController.m 112 2005-10-23 06:31:51Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "Task.h"
#import "TaskMaster.h"
#import "RipperTask.h"
#import "EncoderTask.h"

@implementation Task

- (id) init
{
	@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Task::init called" userInfo:nil];
}

- (id) initWithDisc:(CompactDisc*) disc forTrack:(Track*) track outputFilename:(NSString*) filename
{
	if(self = [super init]) {
		_disc			= [disc retain];
		_track			= [track retain];
		_filename		= [filename retain];

		// Set up the track name
		NSString			*discArtist			= [_disc valueForKey:@"artist"];
		NSString			*trackArtist		= [_track valueForKey:@"artist"];
		NSString			*artist;
		NSString			*trackTitle			= [_track valueForKey:@"title"];
		
		artist = trackArtist;
		if(nil == artist) {
			artist = discArtist;
			if(nil == artist) {
				artist = @"Unknown Artist";
			}
		}
		if(nil == trackTitle) {
			trackTitle = @"Unknown Track";
		}
		_trackName = [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
		
		_ripperTask		= [[[RipperTask alloc] initWithDisc:_disc forTrack:_track trackName:_trackName] retain];
		_encoderTask	= [[[EncoderTask alloc] initWithSource:[_ripperTask valueForKey:@"path"] target:_filename trackName:_trackName] retain];

		[_ripperTask addObserver:self forKeyPath:@"completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
		[_ripperTask addObserver:self forKeyPath:@"stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	

		[_encoderTask addObserver:self forKeyPath:@"completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
		[_encoderTask addObserver:self forKeyPath:@"stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
	}
	return self;
}

- (void) dealloc
{
	[_disc release];
	[_track release];
	[_filename release];
	
	[_ripperTask removeObserver:self forKeyPath:@"completed"];
	[_ripperTask removeObserver:self forKeyPath:@"stopped"];
	
	[_ripperTask release];

	[_encoderTask removeObserver:self forKeyPath:@"completed"];
	[_encoderTask removeObserver:self forKeyPath:@"stopped"];
	
	[_encoderTask release];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString*) keyPath ofObject:(id) object change:(NSDictionary*) change context:(void*) context
{
	// We handle ripping and encoding tasks the same way
	if([keyPath isEqual:@"completed"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(runTask:) withObject:self waitUntilDone:FALSE];
	}
	else if([keyPath isEqual:@"stopped"]) {
		if(YES == [object isKindOfClass:[EncoderTask class]]) {
			[_ripperTask removeTemporaryFile];
		}
		[[TaskMaster sharedController] removeTask:self];
	}
}

@end
