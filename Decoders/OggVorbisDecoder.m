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

#import "OggVorbisDecoder.h"
#import "CircularBuffer.h"

@implementation OggVorbisDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {		
		FILE *file = fopen([[self filename] fileSystemRepresentation], "r");
		NSAssert1(NULL != file, @"Unable to open the input file (%s).", strerror(errno));	
		
		int result = ov_test(file, &_vf, NULL, 0);
		NSAssert(0 == result, NSLocalizedStringFromTable(@"The file does not appear to be a valid Ogg Vorbis file.", @"Exceptions", @""));
		
		result = ov_test_open(&_vf);
		NSAssert(0 == result, NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @""));
		
		// Get input file information
		vorbis_info *ovInfo = ov_info(&_vf, -1);
		
		NSAssert(NULL != ovInfo, @"Unable to get information on Ogg Vorbis stream.");
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= ovInfo->rate;
		_pcmFormat.mChannelsPerFrame	= ovInfo->channels;
		_pcmFormat.mBitsPerChannel		= 16;
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	}
	return self;
}

- (void) dealloc
{
	int result = ov_clear(&_vf); 
	
	if(0 != result)
		NSLog(@"ov_clear failed");

	[super dealloc];
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"Ogg (Vorbis, %u channels, %u Hz)", [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return ov_pcm_total(&_vf, -1); }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	if(ov_pcm_seek(&_vf, frame)) {
		[[self pcmBuffer] reset];
		_currentFrame = frame;
	}
	
	return [self currentFrame];
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer;
	long				bytesRead;
	long				totalBytes;
	void				*rawBuffer;
	NSUInteger			availableSpace;
	int					currentSection;
	
	buffer				= [self pcmBuffer];
	rawBuffer			= [buffer exposeBufferForWriting];
	availableSpace		= [buffer freeSpaceAvailable];
	totalBytes			= 0;
	currentSection		= 0;
	
	for(;;) {
		bytesRead		= ov_read(&_vf, rawBuffer + totalBytes, (int)(availableSpace - totalBytes), YES, sizeof(int16_t), YES, &currentSection);
		
		NSAssert(0 <= bytesRead, @"Ogg Vorbis decode error.");
		
		totalBytes += bytesRead;
		
		if(0 == bytesRead || totalBytes >= availableSpace) {
			break;
		}
	}
	
	[buffer wroteBytes:totalBytes];
}

@end
