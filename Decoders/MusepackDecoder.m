/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import "MusepackDecoder.h"
#import "CircularBuffer.h"

@implementation MusepackDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		_file = fopen([[self filename] fileSystemRepresentation], "r");
		NSAssert1(NULL != _file, @"Unable to open the input file (%s).", strerror(errno));	
		
		mpc_reader_setup_file_reader(&_reader_file, _file);
		
		// Get input file information
		mpc_streaminfo_init(&_streaminfo);
		mpc_int32_t intResult = mpc_streaminfo_read(&_streaminfo, &_reader_file.reader);
		NSAssert(ERROR_CODE_OK == intResult, NSLocalizedStringFromTable(@"The file does not appear to be a valid Musepack file.", @"Exceptions", @""));
		
		// Set up the decoder
		mpc_decoder_setup(&_decoder, &_reader_file.reader);
		mpc_bool_t boolResult = mpc_decoder_initialize(&_decoder, &_streaminfo);
		NSAssert(YES == boolResult, NSLocalizedStringFromTable(@"Unable to intialize the Musepack decoder.", @"Exceptions", @""));
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= _streaminfo.sample_freq;
		_pcmFormat.mChannelsPerFrame	= _streaminfo.channels;
		_pcmFormat.mBitsPerChannel		= 16;
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
	}
	return self;
}

- (void) dealloc
{
	int result = fclose(_file);
	_file = NULL;
	NSAssert1(EOF != result, @"Unable to close the input file (%s).", strerror(errno));	
	
	[super dealloc];
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Musepack", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return mpc_streaminfo_get_length_samples(&_streaminfo); }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	if(mpc_decoder_seek_sample(&_decoder, frame)) {
		[[self pcmBuffer] reset]; 
		_currentFrame = frame;
	}
	
	return [self currentFrame]; 
}

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	unsigned			spaceRequired		= MPC_FRAME_LENGTH * [self pcmFormat].mChannelsPerFrame * ([self pcmFormat].mBitsPerChannel / 8);
	
	if(spaceRequired <= [buffer freeSpaceAvailable]) {
		MPC_SAMPLE_FORMAT		mpcBuffer			[MPC_DECODER_BUFFER_LENGTH];
		mpc_uint32_t			framesRead			= 0;
		unsigned				sample				= 0;
		
		// Decode the data
		framesRead		= mpc_decoder_decode(&_decoder, mpcBuffer, 0, 0);
		NSAssert((mpc_uint32_t)-1 != framesRead, NSLocalizedStringFromTable(@"Musepack decoding error.", @"Exceptions", @""));
		
#ifdef MPC_FIXED_POINT
#error "Fixed point not yet supported"
#else
		int32_t					audioSample			= 0;
		int8_t					*alias8				= NULL;
		int16_t					*alias16			= NULL;
		int32_t					*alias32			= NULL;
        int32_t					clipMin				= -1 << ([self pcmFormat].mBitsPerChannel - 1);
		int32_t					clipMax				= (1 << ([self pcmFormat].mBitsPerChannel - 1)) - 1;

		switch([self pcmFormat].mBitsPerChannel) {
			
			case 8:
				
				// No need for byte swapping
				alias8 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 7);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					*alias8++		= (int8_t)audioSample;
				}
					
				[buffer wroteBytes:framesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int8_t)];
				
				break;
				
			case 16:
				
				// Convert to big endian byte order 
				alias16 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 15);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					*alias16++		= (int16_t)OSSwapHostToBigInt16(audioSample);
				}
					
				[buffer wroteBytes:framesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];
				
				break;
				
			case 24:
				
				// Convert to big endian byte order 
				alias8 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 23);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					audioSample		= OSSwapHostToBigInt32(audioSample);
					*alias8++		= (int8_t)(audioSample >> 16);
					*alias8++		= (int8_t)(audioSample >> 8);
					*alias8++		= (int8_t)audioSample;
				}
					
				[buffer wroteBytes:framesRead * [self pcmFormat].mChannelsPerFrame * 3 * sizeof(int8_t)];
				
				break;
				
			case 32:
				
				// Convert to big endian byte order 
				alias32 = [buffer exposeBufferForWriting];
				for(sample = 0; sample < framesRead * [self pcmFormat].mChannelsPerFrame; ++sample) {
					audioSample		= mpcBuffer[sample] * (1 << 31);
					audioSample		= (audioSample < clipMin ? clipMin : (audioSample > clipMax ? clipMax : audioSample));
					*alias32++		= OSSwapHostToBigInt32(audioSample);
				}
					
				[buffer wroteBytes:framesRead * [self pcmFormat].mChannelsPerFrame * sizeof(int32_t)];
				
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;	
		}
#endif /* MPC_FIXED_POINT */
	}
}

@end
