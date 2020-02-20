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

#import "OggSpeexDecoder.h"
#import "CircularBuffer.h"

#include <speex/speex.h>
#include <speex/speex_header.h>
#include <speex/speex_stereo.h>
#include <speex/speex_callbacks.h>

@interface OggSpeexDecoder (Private)
- (void)		incrementPacketCount;
- (void)		setFramesPerPacket:(unsigned)framesPerPacket;
- (void)		setExtraHeaderCount:(unsigned)extraHeaderCount;
@end

@implementation OggSpeexDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		ogg_packet				op;
		SpeexStereoState		stereo					= SPEEX_STEREO_STATE_INIT;
		
		// Open the input file
		_fd = open([[self filename] fileSystemRepresentation], O_RDONLY);
		NSAssert1(-1 != _fd, @"Unable to open the input file (%s).", strerror(errno));
		
		// Initialize Ogg data struct
		ogg_sync_init(&_oy);
		
		// Get the ogg buffer for writing
		char *data = ogg_sync_buffer(&_oy, 4096);
		
		// Read bitstream from input file
		ssize_t bytesRead = read(_fd, data, 4096);
		NSAssert1(-1 != bytesRead, @"Unable to read from the input file (%s).", strerror(errno));
		
		// Tell the sync layer how many bytes were written to its internal buffer
		int result = ogg_sync_wrote(&_oy, bytesRead);
		NSAssert(-1 != result, @"Ogg decoding error (ogg_sync_wrote).");
		
		// Turn the data we wrote into an ogg page
		result = ogg_sync_pageout(&_oy, &_og);
		NSAssert(1 == result, @"The file does not appear to be an Ogg bitstream.");
		
		// Initialize the stream and grab the serial number
		ogg_stream_init(&_os, ogg_page_serialno(&_og));
		
		// Get the first Ogg page
		result = ogg_stream_pagein(&_os, &_og);
		NSAssert(0 == result, @"Error reading first page of Ogg bitstream data.");
		
		// Get the first packet (should be the header) from the page
		result = ogg_stream_packetout(&_os, &op);
		NSAssert(1 == result, @"Error reading initial Ogg packet header.");

		[self incrementPacketCount];
		
		// Convert the packet to the Speex header
		SpeexHeader *header = speex_packet_to_header((char*)op.packet, (int)op.bytes);
		NSAssert(NULL != header, @"Unable to read the Speex header.");
		NSAssert1(SPEEX_NB_MODES > header->mode, NSLocalizedStringFromTable(@"The Speex mode number %i was not recognized.", @"Exceptions", @""), header->mode);
		
		const SpeexMode *mode = speex_lib_get_mode(header->mode);
		NSAssert1(1 >= header->speex_version_id, NSLocalizedStringFromTable(@"Unable to decode Speex bitstream version %i.", @"Exceptions", @""), header->speex_version_id);
		NSAssert(mode->bitstream_version == header->mode_bitstream_version, NSLocalizedStringFromTable(@"This file was encoded with a different version of Speex.", @"Exceptions", @""));
		//	NSAssert(mode->bitstream_version > header->mode_bitstream_version, NSLocalizedStringFromTable(@"This file was encoded with a newer version of Speex.", @"Exceptions", @""));
		//	NSAssert(mode->bitstream_version < header->mode_bitstream_version, NSLocalizedStringFromTable(@"This file was encoded with an older version of Speex.", @"Exceptions", @""));
		
		// Initialize the decoder
		_st = speex_decoder_init(mode);
		NSAssert(NULL != _st, NSLocalizedStringFromTable(@"Unable to intialize the Speex decoder.", @"Exceptions", @""));
		
		// Initialize the speex bit-packing data structure
		speex_bits_init(&_bits);
		
		// Initialize the stereo mode
		//	_stereo		= SPEEX_STEREO_STATE_INIT;
		memcpy(&_stereo, &stereo, sizeof(SpeexStereoState));
		
		speex_decoder_ctl(_st, SPEEX_SET_SAMPLING_RATE, &header->rate);
		
		[self setFramesPerPacket:(0 == header->frames_per_packet ? 1 : header->frames_per_packet)];
		[self setExtraHeaderCount:header->extra_headers];
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= header->rate;
		_pcmFormat.mChannelsPerFrame	= header->nb_channels;
		_pcmFormat.mBitsPerChannel		= 16;
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
		
		free(header);
	}
	return self;
}

- (void) dealloc
{
	int			result;
	
	// Speex cleanup
	speex_decoder_destroy(_st);
	speex_bits_destroy(&_bits);

	// Ogg cleanup
	ogg_stream_clear(&_os);
	ogg_sync_clear(&_oy);
	
	// Close input file
	result = close(_fd);
	NSAssert1(-1 != result, @"Unable to close the input file (%s).", strerror(errno));

	[super dealloc];
}

- (NSUInteger)		packetCount						{ return _packetCount; }
- (NSUInteger)		framesPerPacket					{ return _framesPerPacket; }
- (NSUInteger)		extraHeaderCount				{ return _extraHeaderCount; }

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"Ogg (Speex, %u channels, %u Hz)", [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }
- (SInt64)			totalFrames						{ return -1; }

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	int					frameSize			= 0;
	NSUInteger			packetsDesired;

	// Calculate how many Speex packets we have space for in buffer
	speex_decoder_ctl(_st, SPEEX_GET_FRAME_SIZE, &frameSize);
	packetsDesired	= [buffer freeSpaceAvailable] / (frameSize * [self framesPerPacket] * [self pcmFormat].mChannelsPerFrame * sizeof(spx_int16_t));
	
	// Attempt to process the desired number of packets
	while(0 < packetsDesired && NO == ogg_stream_eos(&_os)) {
		ogg_packet			op;
		int					result;
		
		// Process any packets in the current page
		while(0 < packetsDesired && NO == ogg_stream_eos(&_os)) {

			// Grab a packet from the streaming layer
			result		= ogg_stream_packetout(&_os, &op);
			NSAssert(-1 != result, @"Ogg loss of streaming.");
			
			// If result is 0, there is insufficient data to assemble a packet
			if(0 == result) {
				break;
			}
			
			// Otherwise, we got a valid packet for processing
			if(1 == result) {

				// Ignore the following:
				//  - Speex comments in packet #2
				//  - Extra headers (optionally) in packets 3+
				if(1 != [self packetCount] && 1 + [self extraHeaderCount] <= [self packetCount]) {
					unsigned		i, j;
					spx_int16_t		output [2000];
					int16_t			*alias;
					
					// Copy the Ogg packet to the Speex bitstream
					speex_bits_read_from(&_bits, (char*)op.packet, (int)op.bytes);

					// Decode each frame in the Speex packet
					for(i = 0; i < [self framesPerPacket]; ++i) {

						result		= speex_decode_int(_st, &_bits, output);
						NSAssert(-2 != result, NSLocalizedStringFromTable(@"Decoding error: possible corrupted stream.", @"Exceptions", @""));
						NSAssert(0 < speex_bits_remaining(&_bits), NSLocalizedStringFromTable(@"Decoding overflow: possible corrupted stream.", @"Exceptions", @""));
						
						// -1 indicates EOS
						if(-1 == result) {
							break;
						}
						
						// Process stereo channel, if present
						if(2 == [self pcmFormat].mChannelsPerFrame) {
							speex_decode_stereo_int(output, frameSize, &_stereo);
						}

						// Convert to big endian and place in buffer
						alias	= [buffer exposeBufferForWriting];
						for(j = 0; j < frameSize * [self pcmFormat].mChannelsPerFrame; ++j) {
							*alias++ = OSSwapHostToBigInt16(output[j]);
						}

						[buffer wroteBytes:frameSize * [self pcmFormat].mChannelsPerFrame * sizeof(int16_t)];

						// Packet processing finished
						--packetsDesired;
					}
				}
			}
			
			// Finished with this packet
			[self incrementPacketCount];
		}
		
		// Grab a new Ogg page for processing, if necessary
		if(NO == ogg_stream_eos(&_os) && 0 < packetsDesired) {
			while(1 != ogg_sync_pageout(&_oy, &_og)) {
				char			*data		= NULL;
				ssize_t			bytesRead;
				
				// Get the ogg buffer for writing
				data		= ogg_sync_buffer(&_oy, 4196);
				
				// Read bitstream from input file
				bytesRead	= read(_fd, data, 4196);
				NSAssert1(-1 != bytesRead, @"Unable to read from the input file (%s).", strerror(errno));
								
				ogg_sync_wrote(&_oy, bytesRead);

				// No more data available from input file
				if(0 == bytesRead) {
					break;
				}
			}
			
			// Get the resultant Ogg page
			result		= ogg_stream_pagein(&_os, &_og);
			NSAssert(0 == result, @"Error reading Ogg page.");
		}
	}
}

@end

@implementation OggSpeexDecoder (Private)

- (void)		incrementPacketCount								{ _packetCount++; }

- (void)		setFramesPerPacket:(unsigned)framesPerPacket		{ _framesPerPacket = framesPerPacket; }
- (void)		setExtraHeaderCount:(unsigned)extraHeaderCount		{ _extraHeaderCount = extraHeaderCount; }

@end
