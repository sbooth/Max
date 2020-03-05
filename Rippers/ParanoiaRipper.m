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

#import "ParanoiaRipper.h"
#import "Track.h"
#import "SectorRange.h"
#import "LogController.h"
#import "CompactDiscDocument.h"
#import "CompactDisc.h"
#import "StopException.h"

#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close
#include <paths.h>			// _PATH_DEV

// Tag values for NSPopupButton
enum {
	PARANOIA_LEVEL_FULL					= 0,
	PARANOIA_LEVEL_OVERLAP_CHECKING		= 1
};

@interface ParanoiaRipper (Private)
- (BOOL)	logActivity;
- (void)	ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file;
@end

// cdparanoia callback
/*static char *callback_strings[15] = {
	"wrote",
	"finished",
	"read",
	"verify",
	"jitter",
	"correction",
	"scratch",
	"scratch repair",
	"skip",
	"drift",
	"backoff",
	"overlap",
	"dropped",
	"duped",
	"transport error"
};*/

static void 
callback(long inpos, int function, void *userdata)
{
//	ParanoiaRipper *ripper = (ParanoiaRipper *)userdata;
	
/*	if([ripper logActivity]) {
		[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Rip status: %s sector %ld (%ld)", @"Log", @""), (function >= -2 && function <= 13 ? callback_strings[function + 2] : ""), inpos / CD_FRAMEWORDS, inpos] waitUntilDone:NO];
	}*/
}

@implementation ParanoiaRipper

+ (void) initialize
{
	NSString				*paranoiaDefaultsValuesPath;
    NSDictionary			*paranoiaDefaultsValuesDictionary;
    
	@try {
		paranoiaDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"ParanoiaDefaults" ofType:@"plist"];
		NSAssert1(nil != paranoiaDefaultsValuesPath, NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @""), @"ParanoiaDefaults.plist");

		paranoiaDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:paranoiaDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:paranoiaDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"ParanoiaRipper"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName
{
	if((self = [super initWithSectors:sectors deviceName:deviceName])) {
		int			paranoiaLevel	= 0;
		int			paranoiaMode	= PARANOIA_MODE_DISABLE;
		int			result;
		NSString	*bsdName		= [NSString stringWithFormat:@"%sr%@", _PATH_DEV, deviceName];

		// Setup cdparanoia
		_drive		= cdda_identify([bsdName fileSystemRepresentation], 0, NULL);
		NSAssert1(NULL != _drive, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"cdda_identify");
		
		result = cdda_open(_drive);
		NSAssert1(0 == result, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"cdda_open");
		
		_paranoia	= paranoia_init(_drive);
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaEnable"]) {
			paranoiaMode = PARANOIA_MODE_FULL ^ PARANOIA_MODE_NEVERSKIP; 
			
			paranoiaLevel = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"paranoiaLevel"];
			
			if(PARANOIA_LEVEL_FULL == paranoiaLevel) {
			}
			else if(PARANOIA_LEVEL_OVERLAP_CHECKING == paranoiaLevel) {
				paranoiaMode |= PARANOIA_MODE_OVERLAP;
				paranoiaMode &= ~PARANOIA_MODE_VERIFY;
			}
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"paranoiaNeverSkip"]) {
				paranoiaMode |= PARANOIA_MODE_NEVERSKIP;
				_maximumRetries = -1;
			}
			else {
				_maximumRetries = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"paranoiaMaximumRetries"];
			}
		}
		else {
			paranoiaMode = PARANOIA_MODE_DISABLE;
		}
		
		paranoia_modeset(_paranoia, paranoiaMode);
		
		// Determine the size of the track(s) we are ripping
		[self setValue:[_sectors valueForKeyPath:@"@sum.length"] forKey:@"grandTotalSectors"];			
				
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
//	cdda_close(_drive);
	paranoia_free(_paranoia);

	[super dealloc];
}

- (oneway void) ripToFile:(NSString *)filename
{
	OSStatus						err;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioStreamBasicDescription		outputASBD;
	SectorRange						*range;
	
	@try {
		// Tell our owner we are starting
		_startTime = [NSDate date];
		[[self delegate] setStartTime:_startTime];
		[[self delegate] setStarted:YES];
		[[self delegate] setPhase:NSLocalizedStringFromTable(@"Ripping", @"General", @"")];

		// Setup output file type (same)
		bzero(&outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Interleaved 16-bit PCM audio
		outputASBD.mSampleRate			= 44100.f;
		outputASBD.mFormatID			= kAudioFormatLinearPCM;
		outputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
		outputASBD.mBytesPerPacket		= 4;
		outputASBD.mFramesPerPacket		= 1;
		outputASBD.mBytesPerFrame		= 4;
		outputASBD.mChannelsPerFrame	= 2;
		outputASBD.mBitsPerChannel		= 16;

		err = AudioFileCreateWithURL((CFURLRef)[NSURL fileURLWithPath:filename], kAudioFileCAFType, &outputASBD, kAudioFileFlags_EraseFile, &audioFile);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileCreateWithURL", UTCreateStringForOSType(err));
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID", UTCreateStringForOSType(err));
		
		for(range in _sectors) {
			[self ripSectorRange:range toFile:extAudioFileRef];
			_sectorsRead = [NSNumber numberWithUnsignedLong:[_sectorsRead unsignedLongValue] + [range length]];
		}
	}

	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		NSException						*exception;
		
		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [NSException exceptionWithName:@"CoreAudioException"
												reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [NSException exceptionWithName:@"CoreAudioException"
												reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the device file descriptor
		cdda_close(_drive);
	}
	
	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (void) ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file
{
	unsigned long		cursor				= [range firstSector];
	unsigned long		lastSector			= [range lastSector];
	int16_t				*buf				= NULL;
	unsigned long		grandTotalSectors	= [_grandTotalSectors unsignedLongValue];
	unsigned long		sectorsToRead		= grandTotalSectors - [_sectorsRead unsignedLongValue];
	long				where;
	unsigned long		iterations			= 0;
	OSStatus			err;
	AudioBufferList		bufferList;
	UInt32				frameCount;
	double				percentComplete;
	NSTimeInterval		interval;
	unsigned			secondsRemaining;
	
	// Go to the range's first sector in preparation for reading
	where = paranoia_seek(_paranoia, cursor, SEEK_SET);   	    
	if(-1 == where) {
		[[self delegate] setStopped:YES];
		@throw [NSException exceptionWithName:@"ParanoiaException"
									   reason:NSLocalizedStringFromTable(@"Unable to access the disc.", @"Exceptions", @"")
									 userInfo:nil];
	}

	// Rip the track
	while(cursor <= lastSector) {
		
		// Read a chunk
		buf = paranoia_read_limited(_paranoia, callback, self, (-1 == _maximumRetries ? 20 : _maximumRetries));
		NSAssert(NULL != buf, NSLocalizedStringFromTable(@"The skip tolerance was exceeded.", @"Exceptions", @""));
		
		// Put the data in an AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mData				= buf;
		bufferList.mBuffers[0].mDataByteSize		= CD_FRAMESIZE_RAW;
		bufferList.mBuffers[0].mNumberChannels		= 2;
		
		frameCount									= CD_FRAMESIZE_RAW / 4;
		
		// Write the data
		err = ExtAudioFileWrite(file, frameCount, &bufferList);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite", UTCreateStringForOSType(err));
				
		// Update status
		sectorsToRead--;
		
		// Distributed Object calls are expensive, so only perform them every few iterations
		if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
			
			// Check if we should stop, and if so throw an exception
			if([[self delegate] shouldStop]) {
				@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
			}
			
			// Update UI
			percentComplete		= ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) * 100.0;
			interval			= -1.0 * [_startTime timeIntervalSinceNow];
			secondsRemaining	= interval / ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) - interval;
			
			[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
		}
		
		++iterations;

		// Advance cursor
		++cursor;
	}
}

@end
