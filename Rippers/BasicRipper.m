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

#import "BasicRipper.h"
#import "SectorRange.h"
#import "LogController.h"
#import "StopException.h"

#include <IOKit/storage/IOCDTypes.h>

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
	[_drive release];	_drive = nil;
	
	[super dealloc];
}

- (oneway void) ripToFile:(NSString *)filename
{
	OSStatus						err;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioStreamBasicDescription		outputASBD;
	SectorRange						*range;
	
	// Tell our owner we are starting
	_startTime = [NSDate date];
	[[self delegate] setStartTime:_startTime];
	[[self delegate] setStarted:YES];
	[[self delegate] setPhase:NSLocalizedStringFromTable(@"Ripping", @"General", @"")];
	
	@try {
		// Setup output file type (same)
		bzero(&outputASBD, sizeof(AudioStreamBasicDescription));
		
		// Interleaved 16-bit PCM audio
		outputASBD.mSampleRate			= 44100.f;
		outputASBD.mFormatID			= kAudioFormatLinearPCM;
		outputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
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
			_sectorsRead += [range length];
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
		[_drive closeDevice];
	}
	
	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (void) ripSectorRange:(SectorRange *)range toFile:(ExtAudioFileRef)file
{
	int16_t				*buffer				= NULL;
	NSUInteger			bufferLen			= 0;
	NSUInteger			sectorsRead			= 0;
	NSUInteger			sectorCount			= 0;
	NSUInteger			startSector			= 0;
	NSUInteger			sectorsRemaining	= 0;
	NSUInteger			grandTotalSectors	= _grandTotalSectors;
	NSUInteger			sectorsToRead		= grandTotalSectors - _sectorsRead;
	SectorRange			*readRange			= nil;
	OSStatus			err					= noErr;
	NSUInteger			iterations			= 0;
	AudioBufferList		bufferList;
	UInt32				frameCount			= 0;
	double				percentComplete;
	NSTimeInterval		interval;
	NSUInteger			secondsRemaining;
	
	@try {
		// Allocate a buffer to hold the ripped data
		bufferLen	= [range length] <  1024 ? [range length] : 1024;
		buffer		= calloc(bufferLen, kCDSectorSizeCDDA);
		NSAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		[_drive setSpeed:kCDSpeedMax];
		
		sectorsRemaining = [range length];
		
		while(0 < sectorsRemaining) {
			
			// Set up the parameters for this read
			startSector		= [range firstSector] + [range length] - sectorsRemaining;
			sectorCount		= sectorsRemaining > bufferLen ? bufferLen : sectorsRemaining;
			readRange		= [SectorRange sectorRangeWithFirstSector:startSector sectorCount:sectorCount];
			
			// Extract the audio from the disc
			sectorsRead		= [_drive readAudio:buffer sectorRange:readRange];
			
			NSAssert(sectorCount == sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @""));
			
			// Convert to big endian byte ordering 
			swab(buffer, buffer, [readRange byteSize]);
			
			// Put the data in an AudioBufferList
			bufferList.mNumberBuffers					= 1;
			bufferList.mBuffers[0].mData				= buffer;
			bufferList.mBuffers[0].mDataByteSize		= (UInt32)[readRange byteSize];
			bufferList.mBuffers[0].mNumberChannels		= 2;
			
			frameCount									= (UInt32)([readRange byteSize] / 4);
			
			// Write the data
			err = ExtAudioFileWrite(file, frameCount, &bufferList);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite", UTCreateStringForOSType(err));
			
			// Housekeeping
			sectorsRemaining	-= [readRange length];
			sectorsToRead		-= [readRange length];
			
			// This loop is sufficiently slow that if the delegate is only polled every MAX_DO_POLL_FREQUENCY
			// iterations the user will think the program is unresponsive
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % 2/*MAX_DO_POLL_FREQUENCY*/) {
				
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
		}
	}
	
	@finally {
		free(buffer);	
	}
}

@end
