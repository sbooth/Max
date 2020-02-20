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

#import "ShortenDecoder.h"
#import "CircularBuffer.h"

#define SHORTEN_BLOCKS 512

@implementation ShortenDecoder

- (id) initWithFilename:(NSString *)filename
{
	if((self = [super initWithFilename:filename])) {
		shn_config		config;
		int				result;
		
		// Setup config struct
		config.error_output_method			= ERROR_OUTPUT_STDERR;
		config.seek_tables_path				= NULL;
		config.relative_seek_tables_path	= NULL;
		config.verbose						= 0;
#if defined(__BIG_ENDIAN__)
		config.swap_bytes					= 1;
#elif defined(__LITTLE_ENDIAN__)
		config.swap_bytes					= 0;
#else
#error "Target processor byte order unknown"
#endif
		
		// Setup decoder
		_shn = shn_load((char *)[[self filename] fileSystemRepresentation], config);
		NSAssert(NULL != _shn, @"Unable to open the input file.");
		
		result	= shn_init_decoder(_shn);
		NSAssert(1 == result, @"Unable to initialize the Shorten decoder.");
		
		// Setup input format descriptor
		_pcmFormat.mFormatID			= kAudioFormatLinearPCM;
		_pcmFormat.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
		
		_pcmFormat.mSampleRate			= shn_get_samplerate(_shn);
		_pcmFormat.mChannelsPerFrame	= shn_get_channels(_shn);
		_pcmFormat.mBitsPerChannel		= shn_get_bitspersample(_shn);
		
		_pcmFormat.mBytesPerPacket		= (_pcmFormat.mBitsPerChannel / 8) * _pcmFormat.mChannelsPerFrame;
		_pcmFormat.mFramesPerPacket		= 1;
		_pcmFormat.mBytesPerFrame		= _pcmFormat.mBytesPerPacket * _pcmFormat.mFramesPerPacket;
		
	}
	return self;
}

- (void) dealloc
{
	shn_cleanup_decoder(_shn);
	shn_unload(_shn);
	_shn = NULL;
	
	[super dealloc];
}

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Shorten", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return (shn_get_song_length(_shn) / 1000) * [self pcmFormat].mSampleRate; }
- (SInt64)			seekToFrame:(SInt64)frame		{ return -1; }

- (void) fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	unsigned			spaceRequired		= 0;	
	
	// Determine the size needed for a read
	spaceRequired		= (unsigned)shn_get_buffer_block_size(_shn, SHORTEN_BLOCKS);
		
	while([buffer freeSpaceAvailable] >= spaceRequired) {
		int				bytesRead			= 0;
		void			*rawBuffer			= [buffer exposeBufferForWriting];

		bytesRead		= shn_read(_shn, rawBuffer, spaceRequired);

		// Convert host-ordered data to big-endian
#if __LITTLE_ENDIAN__
		swab(rawBuffer, rawBuffer, bytesRead);
#endif

		[buffer wroteBytes:bytesRead];
		
		// No more data
		if(0 == bytesRead) {
			break;
		}
	}
}

@end
