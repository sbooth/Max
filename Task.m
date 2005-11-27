/*
 *  $Id$
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

- (id) initWithDisc:(CompactDiscDocument *) disc forTrack:(Track *) track outputFilename:(NSString *) filename
{
	if((self = [super init])) {
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
		
		[_track setValue:[NSNumber numberWithBool:YES] forKey:@"ripInProgress"];
		
		if([[_disc valueForKey:@"multiArtist"] boolValue]) {
			_trackName	= [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
		}
		else {
			_trackName	= [NSString stringWithFormat:@"%@", trackTitle];
			
		}
		
		_ripperTask		= [[[RipperTask alloc] initWithDisc:_disc forTrack:_track trackName:_trackName] retain];
		_encoderTask	= [[[EncoderTask alloc] initWithSource:[_ripperTask valueForKey:@"path"] target:_filename trackName:_trackName] retain];

		[_ripperTask addObserver:self forKeyPath:@"ripper.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
		[_ripperTask addObserver:self forKeyPath:@"ripper.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
		[_ripperTask addObserver:self forKeyPath:@"ripper.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	

		[_encoderTask addObserver:self forKeyPath:@"encoder.started" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
		[_encoderTask addObserver:self forKeyPath:@"encoder.completed" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
		[_encoderTask addObserver:self forKeyPath:@"encoder.stopped" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];	
	}
	return self;
}

- (void) dealloc
{
	[_track setValue:[NSNumber numberWithBool:NO] forKey:@"ripInProgress"];

	[_disc release];
	[_track release];
	[_filename release];
	
	[_ripperTask removeObserver:self forKeyPath:@"ripper.started"];
	[_ripperTask removeObserver:self forKeyPath:@"ripper.completed"];
	[_ripperTask removeObserver:self forKeyPath:@"ripper.stopped"];
	
	[_ripperTask release];

	[_encoderTask removeObserver:self forKeyPath:@"encoder.started"];
	[_encoderTask removeObserver:self forKeyPath:@"encoder.completed"];
	[_encoderTask removeObserver:self forKeyPath:@"encoder.stopped"];
	
	[_encoderTask release];
	
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *) keyPath ofObject:(id) object change:(NSDictionary *) change context:(void *) context
{
	if([keyPath isEqualToString:@"ripper.started"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidStart:) withObject:self waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"ripper.stopped"]) {
		[_ripperTask removeTemporaryFile];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidStop:) withObject:self waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"ripper.completed"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(ripDidComplete:) withObject:self waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"encoder.started"]) {
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStart:) withObject:self waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"encoder.stopped"]) {
		[_ripperTask removeTemporaryFile];
		[_encoderTask removeOutputFile];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidStop:) withObject:self waitUntilDone:TRUE];
	}
	else if([keyPath isEqualToString:@"encoder.completed"]) {
		[_ripperTask removeTemporaryFile];
		[[TaskMaster sharedController] performSelectorOnMainThread:@selector(encodeDidComplete:) withObject:self waitUntilDone:TRUE];
	}
}

@end
