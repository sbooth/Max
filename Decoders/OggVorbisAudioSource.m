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

#import "OggVorbisAudioSource.h"
#import "IOException.h"

static size_t
ov_callback_read_func(void *ptr, size_t size, size_t nmemb, void *datasource)
{
	id <ReaderMethods>		reader		= (id <ReaderMethods>)datasource;

	return [reader readData:ptr byteCount:size * nmemb];
}

static int
ov_callback_seek_func(void *datasource, ogg_int64_t offset, int whence)
{
	id <ReaderMethods>		reader		= (id <ReaderMethods>)datasource;
	ReaderSeekType			seekType;

	if(NO == [reader isSeekable]) {
		return -1;
	}
	
	switch(whence) {
		case SEEK_SET:		seekType = kReaderSeekTypeAbsolute;		break;
		case SEEK_CUR:		seekType = kReaderSeekTypeCurrent;		break;
		case SEEK_END:		seekType = kReaderSeekTypeEnd;			break;
	}
	
	return [reader seekToOffset:offset seekType:seekType];	
}

static int
ov_callback_close_func(void *datasource)
{
//	id <ReaderMethods>		reader		= (id <ReaderMethods>)datasource;
	return 0;
}

static long
ov_callback_tell_func(void *datasource)
{
	id <ReaderMethods>		reader		= (id <ReaderMethods>)datasource;
	
	return [reader currentOffset];
}

@implementation OggVorbisAudioSource

- (NSString *)		sourceFormatDescription			{ return [NSString stringWithFormat:@"%@, %u channels, %u Hz", NSLocalizedStringFromTable(@"Ogg Vorbis", @"General", @""), [self pcmFormat].mChannelsPerFrame, (unsigned)[self pcmFormat].mSampleRate]; }

- (SInt64)			totalFrames						{ return ov_pcm_total(&_vf, -1); }
- (SInt64)			currentFrame					{ return ov_pcm_tell(&_vf); }

- (BOOL)			isSeekable						{ return [[self reader] isSeekable]; }
- (SInt64)			seekToFrame:(SInt64)frame		{ ov_pcm_seek(&_vf, frame); return frame; }

- (void)			finalizeSetup
{
	vorbis_info		*ovInfo		= NULL;

	// Setup callbacks
	_callbacks.read_func		= ov_callback_read_func;
	_callbacks.seek_func		= ov_callback_seek_func;
	_callbacks.close_func		= ov_callback_close_func;
	_callbacks.tell_func		= ov_callback_tell_func;
	
	if(0 != ov_test_callbacks([self reader], &_vf, NULL, 0, _callbacks)) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"The file does not appear to be a valid Ogg Vorbis file.", @"Exceptions", @"") userInfo:nil];
	}
	
	if(0 != ov_test_open(&_vf)) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") userInfo:nil];
	}
	
	// Get input file information
	ovInfo							= ov_info(&_vf, -1);

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
	
	[super finalizeSetup];
}

- (void)			fillPCMBuffer
{
	CircularBuffer		*buffer				= [self pcmBuffer];
	long				bytesRead			= 0;
	int					currentSection		= 0;
	
	bytesRead = ov_read(&_vf, [buffer exposeBufferForWriting], [buffer freeSpaceAvailable], YES, sizeof(int16_t), YES, &currentSection);
	NSAssert(0 <= bytesRead, @"Ogg Vorbis decode error.");
	
	[buffer wroteBytes:bytesRead];
}

@end
