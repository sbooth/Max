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

#import "Decoder.h"
#import "UtilityFunctions.h"
#import "CoreAudioUtilities.h"
#import "CoreAudioDecoder.h"
#import "CircularBuffer.h"
#import "FLACDecoder.h"
#import "LibsndfileDecoder.h"
#import "MonkeysAudioDecoder.h"
#import "MPEGDecoder.h"
#import "MusepackDecoder.h"
#import "OggFLACDecoder.h"
#import "OggSpeexDecoder.h"
#import "OggVorbisDecoder.h"
#import "WavPackDecoder.h"
#import "ShortenDecoder.h"
#import "FileFormatNotSupportedException.h"

#include <AudioToolbox/AudioFormat.h>

@implementation Decoder

+ (id) decoderWithFilename:(NSString *)filename
{
	Decoder *result = nil;
		
	// Create the source based on the file's extension
	NSArray			*coreAudioExtensions	= GetCoreAudioExtensions();
	NSArray			*libsndfileExtensions	= GetLibsndfileExtensions();
	NSString		*extension				= [[filename pathExtension] lowercaseString];

	// Determine which type of converter to use and create it
	if([extension isEqualToString:@"ogg"] || [extension isEqualToString:@"oga"]) {
		// Determine the content type of the ogg stream
		OggStreamType type = GetOggStreamType(filename);
		NSAssert(kOggStreamTypeInvalid != type, @"The file does not appear to be an Ogg file.");
		NSAssert(kOggStreamTypeUnknown != type, @"The Ogg file's data format was not recognized.");
		
		switch(type) {
			case kOggStreamTypeVorbis:		result = [[OggVorbisDecoder alloc] initWithFilename:filename];		break;
			case kOggStreamTypeFLAC:		result = [[OggFLACDecoder alloc] initWithFilename:filename];		break;
			case kOggStreamTypeSpeex:		result = [[OggSpeexDecoder alloc] initWithFilename:filename];		break;
			default:																							break;
		}
	}
	else if([extension isEqualToString:@"flac"])
		result = [[FLACDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"oggflac"])
		result = [[OggFLACDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"ape"])
		result = [[MonkeysAudioDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"spx"])
		result = [[OggSpeexDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"wv"])
		result = [[WavPackDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"mpc"])
		result = [[MusepackDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"shn"])
		result = [[ShortenDecoder alloc] initWithFilename:filename];
	else if([extension isEqualToString:@"mp3"])
		result = [[MPEGDecoder alloc] initWithFilename:filename];
	else if([coreAudioExtensions containsObject:extension])
		result = [[CoreAudioDecoder alloc] initWithFilename:filename];
	else if([libsndfileExtensions containsObject:extension])
		result = [[LibsndfileDecoder alloc] initWithFilename:filename];
	else
		@throw [FileFormatNotSupportedException exceptionWithReason:NSLocalizedStringFromTable(@"The file's format was not recognized.", @"Exceptions", @"") userInfo:nil];

	return [result autorelease];
}

- (id) initWithFilename:(NSString *)filename
{
	NSParameterAssert(nil != filename);
	
	if((self = [super init])) {
		_pcmBuffer = [[CircularBuffer alloc] init];
		_filename = [filename retain];
	}
	return self;
}

- (void) dealloc
{
	[_pcmBuffer release];
	_pcmBuffer = nil;
	[_filename release];
	_filename = nil;
	
	[super dealloc];
}

- (NSString *)						filename			{ return [[_filename retain] autorelease]; }

- (AudioStreamBasicDescription)		pcmFormat			{ return _pcmFormat; }
- (CircularBuffer *)				pcmBuffer			{ return [[_pcmBuffer retain] autorelease]; }

- (NSString *) pcmFormatDescription
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

- (UInt32) readAudio:(AudioBufferList *)bufferList frameCount:(UInt32)frameCount
{
	NSParameterAssert(NULL != bufferList);
	NSParameterAssert(0 < bufferList->mNumberBuffers);
	NSParameterAssert(0 < frameCount);
	
	UInt32		framesRead		= 0;	
	UInt32		byteCount		= frameCount * [self pcmFormat].mBytesPerPacket;
	UInt32		bytesRead		= 0;

	NSParameterAssert(bufferList->mBuffers[0].mDataByteSize >= byteCount);
	
	// If there aren't enough bytes in the buffer, fill it as much as possible
	if([[self pcmBuffer] bytesAvailable] < byteCount)
		[self fillPCMBuffer];
	
	// If there still aren't enough bytes available, return what we have
	if([[self pcmBuffer] bytesAvailable] < byteCount)
		byteCount = (UInt32)[[self pcmBuffer] bytesAvailable];
			
	bytesRead								= (UInt32)[[self pcmBuffer] getData:bufferList->mBuffers[0].mData byteCount:byteCount];
	bufferList->mBuffers[0].mNumberChannels	= [self pcmFormat].mChannelsPerFrame;
	bufferList->mBuffers[0].mDataByteSize	= bytesRead;
	framesRead								= bytesRead / [self pcmFormat].mBytesPerFrame;
	
	// Update internal state
	_currentFrame += framesRead;
	
	return framesRead;
}

// Generic implementations for (optional) subclass overriding
- (NSString *)		sourceFormatDescription				{ return nil; }

- (SInt64)			totalFrames							{ return -1; }
- (SInt64)			currentFrame						{ return _currentFrame; }

- (BOOL)			supportsSeeking						{ return NO; }
- (SInt64)			seekToFrame:(SInt64)frame			{ return -1; }

// Subclass implementation is responsible for completely filling in _pcmFormat
- (void)			fillPCMBuffer						{}

@end
