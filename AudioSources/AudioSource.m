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

#import "AudioSource.h"
#import "UtilityFunctions.h"
#import "CoreAudioUtilities.h"
#import "CoreAudioAudioSource.h"
#import "FLACAudioSource.h"
#import "LibsndfileAudioSource.h"
#import "MonkeysAudioAudioSource.h"
#import "MusepackAudioSource.h"
#import "OggFLACAudioSource.h"
#import "OggVorbisAudioSource.h"
#import "SpeexAudioSource.h"
#import "WavPackAudioSource.h"

#include <AudioToolbox/AudioFormat.h>

@implementation AudioSource

+ (id)								audioSourceForFilename:(NSString *)filename
{
	AudioSource			*result			= nil;
		
	// Create the source based on the file's extension
	NSArray			*coreAudioExtensions	= getCoreAudioExtensions();
	NSArray			*libsndfileExtensions	= getLibsndfileExtensions();
	NSString		*extension				= [filename pathExtension];

	// Determine which type of converter to use and create it
	if([extension isEqualToString:@"ogg"]) {

		// Determine the content type of the ogg stream
		OggStreamType	type	= oggStreamType(filename);
		NSAssert(kOggStreamTypeInvalid != type, @"The file does not appear to be an Ogg file.");
		NSAssert(kOggStreamTypeUnknown != type, @"The Ogg file's data format was not recognized.");
		
		switch(type) {
			case kOggStreamTypeVorbis:		result = [[OggVorbisAudioSource alloc] init];		break;
			case kOggStreamTypeFLAC:		result = [[OggFLACAudioSource alloc] init];			break;
			case kOggStreamTypeSpeex:		result = [[SpeexAudioSource alloc] init];			break;
			default:																			break;
		}
	}
	else if([extension isEqualToString:@"flac"]) {
		result = [[FLACAudioSource alloc] init];
	}
	else if([extension isEqualToString:@"oggflac"]) {
		result = [[OggFLACAudioSource alloc] init];
	}
	else if([extension isEqualToString:@"ape"]) {
		result = [[MonkeysAudioAudioSource alloc] init];
	}
	else if([extension isEqualToString:@"spx"]) {
		result = [[SpeexAudioSource alloc] init];
	}
	else if([extension isEqualToString:@"wv"]) {
		result = [[WavPackAudioSource alloc] init];
	}
/*	else if([extension isEqualToString:@"shn"]) {
	}*/
	else if([extension isEqualToString:@"mpc"]) {
		result = [[MusepackAudioSource alloc] init];
	}
/*	else if([coreAudioExtensions containsObject:extension]) {
		result = [[CoreAudioAudioSource alloc] init];
	}*/
	else if([libsndfileExtensions containsObject:extension]) {
		result = [[LibsndfileAudioSource alloc] init];
	}
	
	NSAssert(nil != result, NSLocalizedStringFromTable(@"The file's format was not recognized.", @"Exceptions", @""));
	
	[result setFilename:filename];
	
	return [result autorelease];
}

- (id)								init
{
	if((self = [super init])) {
		_pcmBuffer		= [[CircularBuffer alloc] init];
		return self;
	}
	return nil;
}

- (void)							dealloc
{
	[_pcmBuffer release];		_pcmBuffer = nil;
	[_filename release];		_filename = nil;
	
	[super dealloc];
}

- (NSString *)						filename			{ return [[_filename retain] autorelease]; }

- (void)							setFilename:(NSString *)filename
{
	[_filename release];
	_filename = [filename retain];
	[[self pcmBuffer] reset];
}

- (AudioStreamBasicDescription)		pcmFormat			{ return _pcmFormat; }
- (CircularBuffer *)				pcmBuffer			{ return [[_pcmBuffer retain] autorelease]; }

- (NSString *)						pcmFormatDescription
{
	OSStatus						result;
	UInt32							specifierSize;
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat;
	
	asbd			= _pcmFormat;
	specifierSize	= sizeof(fileFormat);
	result			= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &fileFormat);
	NSAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	
	return [fileFormat autorelease];
}

- (UInt32)							readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	UInt32		framesRead				= 0;
	
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < bufferList->mNumberBuffers);
	NSParameterAssert(0 < frameCount);
	
	UInt32		byteCount		= frameCount * [self pcmFormat].mBytesPerPacket;
	UInt32		bytesRead		= 0;

	NSParameterAssert(bufferList->mBuffers[0].mDataByteSize >= byteCount);
	
	// If there aren't enough bytes in the buffer, fill it as much as possible
	if([[self pcmBuffer] bytesAvailable] < byteCount) {
		[self fillPCMBuffer];
	}
	
	// If there still aren't enough bytes available, return what we have
	if([[self pcmBuffer] bytesAvailable] < byteCount) {
		byteCount = [[self pcmBuffer] bytesAvailable];
	}
			
	bytesRead								= [[self pcmBuffer] getData:bufferList->mBuffers[0].mData byteCount:byteCount];
	bufferList->mBuffers[0].mNumberChannels	= [self pcmFormat].mChannelsPerFrame;
	bufferList->mBuffers[0].mDataByteSize	= bytesRead;
	framesRead								= bytesRead / [self pcmFormat].mBytesPerFrame;
	
	return framesRead;
}

// Generic implementations for subclass overriding
- (NSString *)		sourceFormatDescription				{ return nil; }

- (SInt64)			totalFrames							{ return -1; }
- (SInt64)			currentFrame						{ return -1; }
- (SInt64)			seekToFrame:(SInt64)frame			{ return -1; }

// Subclass implementation is responsible for completely filling in _pcmFormat
- (void)			finalizeSetup						{}
- (void)			fillPCMBuffer						{}

@end
