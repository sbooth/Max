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

#import "BasicRipper.h"
#import "BasicRipperTask.h"
#import "SectorRange.h"
#import "LogController.h"
#import "MallocException.h"
#import "StopException.h"
#import "IOException.h"
#import "CoreAudioException.h"

#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <stdlib.h>			// calloc, free
#include <unistd.h>			// lseek, read
#include <fcntl.h>			// open, close

@interface BasicRipper (Private)
- (void)	ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file;
@end

@implementation BasicRipper

- (id) initWithSectors:(NSArray *)sectors deviceName:(NSString *)deviceName
{
	if((self = [super initWithSectors:sectors deviceName:deviceName])) {
		_drive				= [[Drive alloc] initWithDeviceName:deviceName];
		
		// Determine the size of the track(s) we are ripping
		[self setValue:[_sectors valueForKeyPath:@"@sum.length"] forKey:@"grandTotalSectors"];			
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_drive release];
	[super dealloc];
}

- (oneway void) ripToFile:(NSString *)filename
{
	OSStatus						err;
	FSRef							ref;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioStreamBasicDescription		outputASBD;
	NSEnumerator					*enumerator;
	SectorRange						*range;
	
	// Tell our owner we are starting
	_startTime = [NSDate date];
	[_delegate setStartTime:_startTime];
	[_delegate setStarted];
	[_delegate setPhase:NSLocalizedStringFromTable(@"Ripping", @"Ripper", @"")];
	
	@try {
		// Setup output file type (same)
		bzero(&outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Interleaved 16-bit PCM audio
		outputASBD.mSampleRate			= 44100.f;
		outputASBD.mFormatID			= kAudioFormatLinearPCM;
		outputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian;
		outputASBD.mBytesPerPacket		= 4;
		outputASBD.mFramesPerPacket		= 1;
		outputASBD.mBytesPerFrame		= 4;
		outputASBD.mChannelsPerFrame	= 2;
		outputASBD.mBitsPerChannel		= 16;
		
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &outputASBD, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		enumerator = [_sectors objectEnumerator];
		while((range = [enumerator nextObject])) {
			[self ripSectorRange:range toFile:extAudioFileRef];
			_sectorsRead += [range length];
		}
	}
	
	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		NSException						*exception;
		
		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (void) ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file
{
	int16_t				*buffer				= NULL;
	unsigned			bufferLen			= 0;
	unsigned			sectorsRead			= 0;
	unsigned			sectorCount			= 0;
	unsigned			startSector			= 0;
	unsigned			sectorsRemaining	= 0;
	unsigned			grandTotalSectors	= _grandTotalSectors;
	unsigned			sectorsToRead		= grandTotalSectors - _sectorsRead;
	SectorRange			*readRange			= nil;
	OSStatus			err					= noErr;
	unsigned long		iterations			= 0;
	AudioBufferList		bufferList;
	UInt32				frameCount			= 0;
	
	@try {

		// Allocate a buffer to hold the ripped data
		bufferLen	= [range length] <  1024 ? [range length] : 1024;
		buffer		= calloc(bufferLen, kCDSectorSizeCDDA);
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		[_drive setSpeed:kCDSpeedMax];
		
		sectorsRemaining = [range length];
		
		while(0 < sectorsRemaining) {
			
			// Set up the parameters for this read
			startSector		= [range firstSector] + [range length] - sectorsRemaining;
			sectorCount		= sectorsRemaining > bufferLen ? bufferLen : sectorsRemaining;
			readRange		= [SectorRange rangeWithFirstSector:startSector sectorCount:sectorCount];
			
			// Extract the audio from the disc
			sectorsRead		= [_drive readAudio:buffer sectorRange:readRange];
			
			if(sectorCount != sectorsRead) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the CD", @"Exceptions", @"") userInfo:nil];
			}
			
			// Convert to big endian byte ordering for the AIFF file
			swab(buffer, buffer, [readRange byteSize]);
			
			// Put the data in an AudioBufferList
			bufferList.mNumberBuffers					= 1;
			bufferList.mBuffers[0].mData				= buffer;
			bufferList.mBuffers[0].mDataByteSize		= [readRange byteSize];
			bufferList.mBuffers[0].mNumberChannels		= 2;
			
			frameCount									= [readRange byteSize] / 4;
			
			// Write the data
			err = ExtAudioFileWrite(file, frameCount, &bufferList);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Housekeeping
			sectorsRemaining	-= [readRange length];
			sectorsToRead		-= [readRange length];
			
			// This loop is sufficiently slow that if the delegate is only polled every MAX_DO_POLL_FREQUENCY
			// iterations the user will think the program is unresponsive
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % 2/*MAX_DO_POLL_FREQUENCY*/) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) * 100.0;
				NSTimeInterval interval = -1.0 * [_startTime timeIntervalSinceNow];
				unsigned int secondsRemaining = interval / ((double)(grandTotalSectors - sectorsToRead)/(double) grandTotalSectors) - interval;
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;				
		}
	}
	
	@finally {
		free(buffer);	
	}
}

@end
