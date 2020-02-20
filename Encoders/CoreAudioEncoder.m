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

#import "CoreAudioEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioUnit/AudioCodec.h>

#import "CoreAudioEncoderTask.h"
#import "StopException.h"

#import "Decoder.h"
#import "RegionDecoder.h"

#import "GaplessUtilities.h"

@interface CoreAudioEncoder (Private)

- (AudioFileTypeID)		fileType;
- (UInt32)				formatID;

@end

@implementation CoreAudioEncoder

- (oneway void) encodeToFile:(NSString *)filename
{
	NSDate							*startTime							= [NSDate date];
	NSDictionary					*settings							= nil;
	OSStatus						err;
	AudioBufferList					bufferList;
	size_t							bufferLen							= 0;
	SInt64							totalFrames, framesToRead;
	UInt32							size, frameCount;
	UInt32							bitrate, quality, mode;
	ExtAudioFileRef					extAudioFile						= NULL;
	AudioStreamBasicDescription		asbd;
	AudioConverterRef				converter							= NULL;
	CFArrayRef						converterPropertySettings			= NULL;
	unsigned long					iterations							= 0;
	double							percentComplete;
	NSTimeInterval					interval;
	unsigned						secondsRemaining;
				
	@try {
		bufferList.mBuffers[0].mData = NULL;
		
		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];
		[[self delegate] setStarted:YES];
		
		// Setup the decoder
		id <DecoderMethods> decoder = nil;
		NSString *sourceFilename = [[[self delegate] taskInfo] inputFilenameAtInputFileIndex];
		
		// Create the appropriate kind of decoder
		if(nil != [[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"]) {
			SInt64 startingFrame = [[[[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"] valueForKey:@"startingFrame"] longLongValue];
			UInt32 frameCount = [[[[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"] valueForKey:@"frameCount"] unsignedIntValue];
			decoder = [RegionDecoder decoderWithFilename:sourceFilename startingFrame:startingFrame frameCount:frameCount];
		}
		else
			decoder = [Decoder decoderWithFilename:sourceFilename];
		
		// Parse the encoder settings
		settings				= [[self delegate] encoderSettings];
		
		// Desired output
		bzero(&asbd, sizeof(AudioStreamBasicDescription));
		asbd.mFormatID			= [self formatID];
		asbd.mFormatFlags		= (AudioFormatFlags)[[settings objectForKey:@"formatFlags"] unsignedLongValue];
				
		//asbd.mSampleRate		= [[settings objectForKey:@"sampleRate"] doubleValue];
		asbd.mBitsPerChannel	= (UInt32)[[settings objectForKey:@"bitsPerChannel"] unsignedLongValue];
		
		asbd.mSampleRate		= [decoder pcmFormat].mSampleRate;			
		asbd.mChannelsPerFrame	= [decoder pcmFormat].mChannelsPerFrame;

		// Flesh out output structure for PCM formats
		if(kAudioFormatLinearPCM == asbd.mFormatID) {
			asbd.mFramesPerPacket	= 1;
			asbd.mBytesPerPacket	= asbd.mChannelsPerFrame * (asbd.mBitsPerChannel / 8);
			asbd.mBytesPerFrame		= asbd.mBytesPerPacket * asbd.mFramesPerPacket;
		}
		// Adjust the flags for Apple Lossless
		else if(kAudioFormatAppleLossless == asbd.mFormatID) {
			switch([decoder pcmFormat].mBitsPerChannel) {
				case 16:	asbd.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData;	break;
				case 20:	asbd.mFormatFlags = kAppleLosslessFormatFlag_20BitSourceData;	break;
				case 24:	asbd.mFormatFlags = kAppleLosslessFormatFlag_24BitSourceData;	break;
				case 32:	asbd.mFormatFlags = kAppleLosslessFormatFlag_32BitSourceData;	break;
				default:	asbd.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData;	break;
			}
		}
		
		// Open the output file
		NSURL *url = [NSURL fileURLWithPath:filename];
		NSAssert(nil != url, NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @""));

		err = ExtAudioFileCreateWithURL((CFURLRef)url, [self fileType], &asbd, NULL, kAudioFileFlags_EraseFile, &extAudioFile);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileCreateWithURL", UTCreateStringForOSType(err));

		asbd = [decoder pcmFormat];
		err = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty", UTCreateStringForOSType(err));
		
		// Tweak converter settings
		size	= sizeof(converter);
		err		= ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_AudioConverter, &size, &converter);
		NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileGetProperty", UTCreateStringForOSType(err));
		
		// Only adjust settings if a converter exists
		if(NULL != converter) {
			// Bitrate
			if(nil != [settings objectForKey:@"bitrate"]) {
				bitrate		= [[settings objectForKey:@"bitrate"] intValue] * 1000;
				err			= AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitrate), &bitrate);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));
			}
			
			// Quality
			if(nil != [settings objectForKey:@"quality"]) {
				quality		= [[settings objectForKey:@"quality"] intValue];
				err			= AudioConverterSetProperty(converter, kAudioConverterCodecQuality, sizeof(quality), &quality);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));
			}
			
			// Bitrate mode (this is a semi-hack)
			if(nil != [settings objectForKey:@"vbrAvailable"]) {
				mode		= [[settings objectForKey:@"useVBR"] boolValue] ? kAudioCodecBitRateFormat_VBR : kAudioCodecBitRateFormat_CBR;
				err			= AudioConverterSetProperty(converter, kAudioCodecBitRateFormat, sizeof(mode), &mode);
				NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterSetProperty", UTCreateStringForOSType(err));
			}
			
			// Update
			size	= sizeof(converterPropertySettings);
			err		= AudioConverterGetProperty(converter, kAudioConverterPropertySettings, &size, &converterPropertySettings);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterGetProperty", UTCreateStringForOSType(err));
			
			err = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ConverterConfig, size, &converterPropertySettings);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty", UTCreateStringForOSType(err));
		}					
		
		// Allocate buffer
		bufferLen						= 10 * 1024;
		bufferList.mNumberBuffers		= 1;
		bufferList.mBuffers[0].mData	= calloc(bufferLen, sizeof(uint8_t));
		NSAssert(NULL != bufferList.mBuffers[0].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		totalFrames						= [decoder totalFrames];
		framesToRead					= totalFrames;
		
		// Iteratively get the data and save it to the file
		for(;;) {

			// Set up the buffer parameters
			bufferList.mBuffers[0].mNumberChannels	= [decoder pcmFormat].mChannelsPerFrame;
			bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen;
			frameCount								= bufferList.mBuffers[0].mDataByteSize / [decoder pcmFormat].mBytesPerFrame;
			
			// Read a chunk of PCM input
			frameCount = [decoder readAudio:&bufferList frameCount:frameCount];

			// We're finished if no frames were returned
			if(0 == frameCount)
				break;
			
			// Write the data, encoding/converting in the process
			err = ExtAudioFileWrite(extAudioFile, frameCount, &bufferList);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite", UTCreateStringForOSType(err));
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([[self delegate] shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				percentComplete		= ((double)(totalFrames - framesToRead)/(double) totalFrames) * 100.0;
				interval			= -1.0 * [startTime timeIntervalSinceNow];
				secondsRemaining	= (unsigned) (interval / ((double)(totalFrames - framesToRead)/(double) totalFrames) - interval);
				
				[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
			}
			
			++iterations;
		}
		
		// Write gapless info and accurate bitrate for AAC files
		if((kAudioFileMPEG4Type == [self fileType] || kAudioFileM4AType == [self fileType]) && kAudioFormatMPEG4AAC == [self formatID]) {

			// First close the output files
			err				= ExtAudioFileDispose(extAudioFile);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose", UTCreateStringForOSType(err));
			extAudioFile	= NULL;
		
			// Snow Leopard correctly writes the SMPB atom
			if(floor(NSAppKitVersionNumber) <= 949.0 /* Leopard */)
				addMPEG4AACGaplessInformationAtom(filename, [decoder totalFrames]);
			
			addMPEG4AACBitrateInformationAtom(filename, bitrate, mode);
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
		NSException		*exception;
		
		// Close the output file
		if(NULL != extAudioFile) {
			err = ExtAudioFileDispose(extAudioFile);
			if(noErr != err) {
				exception = [NSException exceptionWithName:@"CoreAudioException" 
													reason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				NSLog(@"%@", exception);
			}
		}

		free(bufferList.mBuffers[0].mData);
	}

	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (NSString *) settingsString
{
	NSDictionary	*settings;
	NSString		*bitrateString;
	NSString		*qualityString;
	int				bitrate			= -1;
	int				quality			= -1;
	
	settings = [[self delegate] encoderSettings];
	
	// Bitrate
	if(nil != [settings objectForKey:@"bitrate"]) {
		bitrate		= [[settings objectForKey:@"bitrate"] intValue];
	}
	
	// Quality
	if(nil != [settings objectForKey:@"quality"]) {
		quality		= [[settings objectForKey:@"quality"] intValue];
	}
	
	bitrateString = (-1 == bitrate ? @"" : [NSString stringWithFormat:@"bitrate=%u", bitrate]);
	qualityString = (-1 == quality ? @"" : [NSString stringWithFormat:@"quality=%u", quality]);

	if(-1 == bitrate && -1 == quality)
		return [NSString stringWithFormat:@"Core Audio '%@' codec", UTCreateStringForOSType([self formatID])];
	else
		return [NSString stringWithFormat:@"Core Audio '%@' codec settings: %@ %@", UTCreateStringForOSType([self formatID]), bitrateString, qualityString];
}

@end

@implementation CoreAudioEncoder (Private)

- (AudioFileTypeID)		fileType		{ return (AudioFileTypeID)[[[[self delegate] encoderSettings] objectForKey:@"fileType"] unsignedLongValue]; }
- (UInt32)				formatID		{ return (UInt32)[[[[self delegate] encoderSettings] objectForKey:@"formatID"] unsignedLongValue]; }

@end
