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

#import "FLACDecoder.h"
#import "CircularBuffer.h"

@interface FLACDecoder (Private)

- (void) setTotalSamples:(FLAC__uint64)totalSamples;

- (void) setSampleRate:(Float64)sampleRate;
- (void) setBitsPerChannel:(UInt32)bitsPerChannel;
- (void) setChannelsPerFrame:(UInt32)channelsPerFrame;

@end

static FLAC__StreamDecoderWriteStatus 
writeCallback(const FLAC__StreamDecoder *decoder, const FLAC__Frame *frame, const FLAC__int32 * const buffer[], void *client_data)
{
	FLACDecoder			*source					= (FLACDecoder *)client_data;

	int8_t				*alias8					= NULL;
	int16_t				*alias16				= NULL;
	int32_t				*alias32				= NULL;
	
	unsigned			sample, channel;
	int32_t				audioSample;
		
	// Calculate the number of audio data points contained in the frame (should be one for each channel)
	unsigned spaceRequired = frame->header.blocksize * frame->header.channels * (frame->header.bits_per_sample / 8);

	// Increase buffer size as required
	if([[source pcmBuffer] freeSpaceAvailable] < spaceRequired)
		[[source pcmBuffer] resize:([[source pcmBuffer] size] + spaceRequired)];

	switch(frame->header.bits_per_sample) {
		
		case 8:

			// Interleave the audio (no need for byte swapping)
			alias8 = [[source pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias8++ = (int8_t)buffer[channel][sample];
				}
			}

			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 16:
			
			// Interleave the audio, converting to big endian byte order 
			alias16 = [[source pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias16++ = (int16_t)OSSwapHostToBigInt16((int16_t)buffer[channel][sample]);
				}
			}
				
			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 24:				
			
			// Interleave the audio, converting to big endian byte order
			alias8 = [[source pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					audioSample	= buffer[channel][sample];
					
					// Skip the highest byte
					*alias8++	= (int8_t)((audioSample & 0x00ff0000) >> 16);
					*alias8++	= (int8_t)((audioSample & 0x0000ff00) >> 8);
					*alias8++	= (int8_t)((audioSample & 0x000000ff) /*>> 0*/);					
				}
			}
			
			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		case 32:
			
			// Interleave the audio, converting to big endian byte order 
			alias32 = [[source pcmBuffer] exposeBufferForWriting];
			for(sample = 0; sample < frame->header.blocksize; ++sample) {
				for(channel = 0; channel < frame->header.channels; ++channel) {
					*alias32++ = OSSwapHostToBigInt32(buffer[channel][sample]);
				}
			}
				
			[[source pcmBuffer] wroteBytes:spaceRequired];
			
			break;
			
		default:
			@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
			break;				
	}
	
	// Always return continue; an exception will be thrown if this isn't the case
	return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

static void
metadataCallback(const FLAC__StreamDecoder *decoder, const FLAC__StreamMetadata *metadata, void *client_data)
{
	FLACDecoder		*source		= (FLACDecoder *)client_data;
	//	const FLAC__StreamMetadata_CueSheet		*cueSheet			= NULL;
	//	FLAC__StreamMetadata_CueSheet_Track		*currentTrack		= NULL;
	//	FLAC__StreamMetadata_CueSheet_Index		*currentIndex		= NULL;
	//	unsigned								i, j;
	
	switch(metadata->type) {
		case FLAC__METADATA_TYPE_STREAMINFO:
			[source setTotalSamples:metadata->data.stream_info.total_samples];
			[source setSampleRate:metadata->data.stream_info.sample_rate];			
			[source setBitsPerChannel:metadata->data.stream_info.bits_per_sample];
			[source setChannelsPerFrame:metadata->data.stream_info.channels];
			break;
			
			/*
			 case FLAC__METADATA_TYPE_CUESHEET:
				 cueSheet = &(metadata->data.cue_sheet);
				 
				 for(i = 0; i < cueSheet->num_tracks; ++i) {
					 currentTrack = &(cueSheet->tracks[i]);
					 
					 FLAC__uint64 offset = currentTrack->offset;
					 
					 for(j = 0; j < currentTrack->num_indices; ++j) {
						 currentIndex = &(currentTrack->indices[j]);					
					 }
				 }
					 break;
				 */
			
		default:
			break;
	}
}

static void
errorCallback(const FLAC__StreamDecoder *decoder, FLAC__StreamDecoderErrorStatus status, void *client_data)
{
//	FLACDecoder		*source		= (FLACDecoder *)client_data;
	
//	@throw [FLACException exceptionWithReason:[NSString stringWithCString:FLAC__StreamDecoderErrorStatusString[status] encoding:NSASCIIStringEncoding] userInfo:nil];
}

@implementation FLACDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		// Create FLAC decoder
		_flac = FLAC__stream_decoder_new();
		NSAssert(NULL != _flac, NSLocalizedStringFromTable(@"Unable to create the FLAC decoder.", @"Exceptions", @""));
		
		// Initialize decoder
		FLAC__StreamDecoderInitStatus status = FLAC__stream_decoder_init_file(_flac, 
																			  [[self filename] fileSystemRepresentation],
																			  writeCallback, 
																			  metadataCallback, 
																			  errorCallback,
																			  self);
		NSAssert1(FLAC__STREAM_DECODER_INIT_STATUS_OK == status, @"FLAC__stream_decoder_init_file failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
		
		/*
		 // Process cue sheets
		 result = FLAC__stream_decoder_set_metadata_respond(flac, FLAC__METADATA_TYPE_CUESHEET);
		 NSAssert(YES == result, @"%s", FLAC__stream_decoder_get_resolved_state_string(_flac));
		 */
		
		// Process metadata
		FLAC__bool result = FLAC__stream_decoder_process_until_end_of_metadata(_flac);
		NSAssert1(YES == result, @"FLAC__stream_decoder_process_until_end_of_metadata failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		//	_pcmFormat.mSampleRate			= FLAC__file_decoder_get_sample_rate(_flac);
		//	_pcmFormat.mChannelsPerFrame	= FLAC__file_decoder_get_channels(_flac);
		//	_pcmFormat.mBitsPerChannel		= FLAC__file_decoder_get_bits_per_sample(_flac);
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
		
		// We only handle a subset of the legal bitsPerChannel for FLAC
		NSAssert(8 == _pcmFormat.mBitsPerChannel || 16 == _pcmFormat.mBitsPerChannel || 24 == _pcmFormat.mBitsPerChannel || 32 == _pcmFormat.mBitsPerChannel, @"Sample size not supported");
		
	}
	return self;
}

- (void) dealloc
{
	FLAC__bool					result;
	
	result = FLAC__stream_decoder_finish(_flac);
	NSAssert1(YES == result, @"FLAC__stream_decoder_finish failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));

	FLAC__stream_decoder_delete(_flac);
	_flac = NULL;
	
	[super dealloc];	
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"FLAC", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return _totalSamples; }

- (BOOL)			supportsSeeking					{ return YES; }

- (SInt64) seekToFrame:(SInt64)frame
{
	NSParameterAssert(0 <= frame && frame <= [self totalFrames]);
	
	if(FLAC__stream_decoder_seek_absolute(_flac, frame)) {
		[[self pcmBuffer] reset];
		_currentFrame = frame;
	}
	
	return [self currentFrame];
}

- (void) fillPCMBuffer
{
	CircularBuffer				*buffer				= [self pcmBuffer];

	FLAC__bool					result;
	
	unsigned					blockSize;
	unsigned					channels;
	unsigned					bitsPerSample;
	unsigned					blockByteSize;

	
	for(;;) {

		// EOS?
		if(FLAC__STREAM_DECODER_END_OF_STREAM == FLAC__stream_decoder_get_state(_flac)) {
			break;
		}
				
		// A problem I've run into is calculating how many times to call process_single, since
		// there is no good way to know in advance the bytes which will be required to hold a FLAC frame.
		// I'll handle it here by checking to see if there is enough space for the block
		// that was just read.  For files with varying block sizes, channels or sample depths
		// this could blow up!
		// It's not feasible to use the maximum possible values, because
		// maxBlocksize(65535) * maxBitsPerSample(32) * maxChannels(8) = 16,776,960 (No 16 MB buffers here!)
		blockSize			= FLAC__stream_decoder_get_blocksize(_flac);
		channels			= FLAC__stream_decoder_get_channels(_flac);
		bitsPerSample		= FLAC__stream_decoder_get_bits_per_sample(_flac); 
		
		blockByteSize		= blockSize * channels * (bitsPerSample / 8);

		// Ensure the buffer is large enough to hold one block
		if([buffer size] < blockByteSize)
			[buffer resize:blockByteSize];

		// Ensure sufficient space remains in the buffer
		if([buffer freeSpaceAvailable] >= blockByteSize) {
			result	= FLAC__stream_decoder_process_single(_flac);
			NSAssert1(YES == result, @"FLAC__stream_decoder_process_single failed: %s", FLAC__stream_decoder_get_resolved_state_string(_flac));
		}
		else {
			break;
		}
	}
}

@end

@implementation FLACDecoder (Private)

- (void)	setTotalSamples:(FLAC__uint64)totalSamples 		{ _totalSamples = totalSamples; }

- (void)	setSampleRate:(Float64)sampleRate				{ _pcmFormat.mSampleRate = sampleRate; }
- (void)	setBitsPerChannel:(UInt32)bitsPerChannel		{ _pcmFormat.mBitsPerChannel = bitsPerChannel; }
- (void)	setChannelsPerFrame:(UInt32)channelsPerFrame	{ _pcmFormat.mChannelsPerFrame = channelsPerFrame; }

@end
