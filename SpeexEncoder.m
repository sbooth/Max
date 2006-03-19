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

#import "SpeexEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <Speex/speex.h>
#include <Speex/speex_header.h>
#include <Speex/speex_stereo.h>
#include <Speex/speex_callbacks.h>
#include <Speex/speex_preprocess.h>

#include <Ogg/ogg.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "MissingResourceException.h"
#import "SpeexException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose

// My (semi-arbitrary) list of supported speex bitrates
static int sSpeexBitrates [13] = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28};

// Tag values for NSPopupButton
enum {
	SPEEX_MODE_NARROWBAND					= 0,
	SPEEX_MODE_WIDEBAND						= 1,
	SPEEX_MODE_ULTRAWIDEBAND				= 2,
	
	SPEEX_TARGET_QUALITY					= 0,
	SPEEX_TARGET_BITRATE					= 1
};

/*                 
Comments will be stored in the Vorbis style.            
It is describled in the "Structure" section of
http://www.xiph.org/ogg/vorbis/doc/v-comment.html

The comment header is decoded as follows:
1) [vendor_length] = read an unsigned integer of 32 bits
2) [vendor_string] = read a UTF-8 vector as [vendor_length] octets
3) [user_comment_list_length] = read an unsigned integer of 32 bits
4) iterate [user_comment_list_length] times {
	5) [length] = read an unsigned integer of 32 bits
6) this iteration's user comment = read a UTF-8 vector as [length] octets
     }
7) [framing_bit] = read a single bit as boolean
8) if ( [framing_bit]  unset or end of packet ) then ERROR
9) done.

If you have troubles, please write to ymnk@jcraft.com.
*/

#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
							((buf[base+2]<<16)&0xff0000)| \
							((buf[base+1]<<8)&0xff00)| \
							(buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
	buf[base+2]=((val)>>16)&0xff; \
		buf[base+1]=((val)>>8)&0xff; \
			buf[base]=(val)&0xff; \
}while(0)

static void comment_init(char **comments, int *length, const char *vendor_string)
{
	int vendor_length = strlen(vendor_string);
	int user_comment_list_length = 0;
	int len = 4+vendor_length+4;
	char *p = (char*)malloc(len);
	if(NULL == p){
	}
	
	writeint(p, 0, vendor_length);
	memcpy(p+4, vendor_string, vendor_length);
	writeint(p, 4+vendor_length, user_comment_list_length);

	*length = len;
	*comments = p;
}

static void comment_add(char **comments, int *length, const char *tag, const char *val)
{
	char* p=*comments;
	int vendor_length=readint(p, 0);
	int user_comment_list_length=readint(p, 4+vendor_length);
	int tag_len=(tag?strlen(tag):0);
	int val_len=strlen(val);
	int len=(*length)+4+tag_len+val_len;
	
	p=(char*)realloc(p, len);
	if(p==NULL){
	}
	
	writeint(p, *length, tag_len+val_len);      /* length of comment */
	if(tag) memcpy(p+*length+4, tag, tag_len);  /* comment */
	memcpy(p+*length+4+tag_len, val, val_len);  /* comment */
	writeint(p, 4+vendor_length, user_comment_list_length+1);
	
	*comments=p;
	*length=len;
}

#undef readint
#undef writeint

@implementation SpeexEncoder

+ (void) initialize
{
	NSString				*speexDefaultsValuesPath;
    NSDictionary			*speexDefaultsValuesDictionary;
    
	@try {
		speexDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"SpeexDefaults" ofType:@"plist"];
		if(nil == speexDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"SpeexDefaults.plist" forKey:@"filename"]];
		}
		speexDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:speexDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:speexDefaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

- (id) initWithPCMFilename:(NSString *)inputFilename
{
	if((self = [super initWithPCMFilename:inputFilename])) {
		
		_mode				= [[NSUserDefaults standardUserDefaults] integerForKey:@"speexMode"];

		_resampleInput		= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexResampleInput"];
		
		_denoiseEnabled		= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexDenoiseInput"];
		_agcEnabled			= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexApplyAGC"];
		
		_target				= [[NSUserDefaults standardUserDefaults] integerForKey:@"speexTarget"];

		_vbrEnabled			= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexEnableVBR"];
		_abrEnabled			= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexEnableABR"];

		_quality			= [[NSUserDefaults standardUserDefaults] integerForKey:@"speexQuality"];
		_bitrate			= sSpeexBitrates[[[NSUserDefaults standardUserDefaults] integerForKey:@"speexBitrate"]] * 1000;
		
		_complexity			= [[NSUserDefaults standardUserDefaults] integerForKey:@"speexComplexity"];

		_vadEnabled			= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexEnableVAD"];
		_dtxEnabled			= [[NSUserDefaults standardUserDefaults] boolForKey:@"speexEnableDTX"];

		_framesPerPacket	= [[NSUserDefaults standardUserDefaults] integerForKey:@"speexFramesPerPacket"];
		
		_writeSettingsToComment		= [[NSUserDefaults standardUserDefaults] boolForKey:@"saveEncoderSettingsInComment"];
			
		return self;
	}
	return nil;
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime									= [NSDate date];

	int							fd											= -1;
	
	void						*speexState									= NULL;
	const SpeexMode				*mode										= NULL;
	SpeexPreprocessState		*preprocess									= NULL;
	SpeexBits					bits;

	int							rate										= 44100;
	int							chan										= 2;
	int							frameID										= -1;
	int							frameSize;
	char						*comments									= NULL;
	int							comments_length;
	int							totalFrames;
	int							framesEncoded;
	int							nbBytes;
	int							lookahead									= 0;
	char						cbits [2000];
	   
	SpeexHeader					header;

	NSString					*bundleVersion;
	
	ogg_stream_state			os;
	ogg_page					og;
	ogg_packet					op;
	
	BOOL						eos											= NO;

	ssize_t						currentBytesWritten							= 0;
	ssize_t						bytesWritten								= 0;

	unsigned long				iterations									= 0;

	AudioBufferList				buf;
	ssize_t						buflen										= 0;
	OSStatus					err;
	FSRef						ref;
	ExtAudioFileRef				extAudioFileRef								= NULL;
	SInt64						totalFileFrames, framesToRead;
	UInt32						size, frameCount;

	int16_t						*iter, *limit;
	
   
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];

	@try {
		buf.mBuffers[0].mData = NULL;
		
		// Open the input file
		err = FSPathMakeRef((const UInt8 *)[_inputFilename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the input file", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_inputFilename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileOpen(&ref, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileOpen failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		size	= sizeof(totalFileFrames);
		err		= ExtAudioFileGetProperty(extAudioFileRef, kExtAudioFileProperty_FileLengthFrames, &size, &totalFileFrames);
		if(err != noErr) {
			@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileGetProperty failed", @"Exceptions", @"")
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		framesToRead = totalFileFrames;
		
		// Resample input if requested
		if(_resampleInput) {
			AudioStreamBasicDescription asbd;
			
			// Determine the desired sample rate
			switch(_mode) {
				case SPEEX_MODE_NARROWBAND:		rate = 8000;		break;
				case SPEEX_MODE_WIDEBAND:		rate = 16000;		break;
				case SPEEX_MODE_ULTRAWIDEBAND:	rate = 32000;		break;
					
				default:						
					@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex mode" userInfo:nil];
					break;
			}
			
			asbd.mSampleRate			= (float)rate;
			asbd.mFormatID				= kAudioFormatLinearPCM;
			asbd.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian;
			asbd.mBytesPerPacket		= 4;
			asbd.mFramesPerPacket		= 1;
			asbd.mBytesPerFrame			= 4;
			asbd.mChannelsPerFrame		= 2;
			asbd.mBitsPerChannel		= 16;
			
			err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileSetProperty failed", @"Exceptions", @"")
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		// Open the output file
		fd = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Check if we should stop, and if so throw an exception
		if([_delegate shouldStop]) {
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Initialize ogg stream- use the current time as the stream id
		srand(time(NULL));
		if(-1 == ogg_stream_init(&os, rand())) {
			@throw [SpeexException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to initialize ogg stream", @"Exceptions", @"") userInfo:nil];
		}
		
		
		// Setup encoder from user defaults
		switch(_mode) {
			case SPEEX_MODE_NARROWBAND:		mode = speex_lib_get_mode(SPEEX_MODEID_NB);		break;
			case SPEEX_MODE_WIDEBAND:		mode = speex_lib_get_mode(SPEEX_MODEID_WB);		break;
			case SPEEX_MODE_ULTRAWIDEBAND:	mode = speex_lib_get_mode(SPEEX_MODEID_UWB);	break;
				
			default:						
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex mode" userInfo:nil];
				break;
		}
		
		speex_init_header(&header, rate, 1, mode);
		
		header.frames_per_packet	= _framesPerPacket;
		header.vbr					= _vbrEnabled;
		header.nb_channels			= chan;
		
		// Setup the encoder
		speexState = speex_encoder_init(mode);
		
		speex_encoder_ctl(speexState, SPEEX_SET_COMPLEXITY, &_complexity);
		speex_encoder_ctl(speexState, SPEEX_SET_SAMPLING_RATE, &rate);
		speex_encoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
		
		switch(_target) {
			case SPEEX_TARGET_QUALITY:
					speex_encoder_ctl(speexState, (_vbrEnabled ? SPEEX_SET_VBR_QUALITY : SPEEX_SET_QUALITY), &_quality);
				break;
			case SPEEX_TARGET_BITRATE:
				speex_encoder_ctl(speexState, SPEEX_SET_BITRATE, &_bitrate);
				break;
			default:
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex target" userInfo:nil];
				break;
		}
		
		speex_encoder_ctl(speexState, SPEEX_SET_VBR, &_vbrEnabled);
		speex_encoder_ctl(speexState, SPEEX_SET_ABR, &_abrEnabled);
		speex_encoder_ctl(speexState, SPEEX_SET_VAD, &_vadEnabled);
		if(_vadEnabled) {
			speex_encoder_ctl(speexState, SPEEX_SET_DTX, &_dtxEnabled);
		}
		
		speex_encoder_ctl(speexState, SPEEX_GET_LOOKAHEAD, &lookahead);
		
		if(_denoiseEnabled || _agcEnabled) {
			lookahead	+= frameSize;
			preprocess	= speex_preprocess_state_init(frameSize, rate);
			speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_DENOISE, &_denoiseEnabled);
			speex_preprocess_ctl(preprocess, SPEEX_PREPROCESS_SET_AGC, &_agcEnabled);
		}
		
		// Write header
		op.packet		= (unsigned char *)speex_header_to_packet(&header, (int*)&(op.bytes));
		op.b_o_s		= 1;
		op.e_o_s		= 0;
		op.granulepos	= 0;
		op.packetno		= 0;
		
		ogg_stream_packetin(&os, &op);
		free(op.packet);
		
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		
		comment_init(&comments, &comments_length, [[NSString stringWithFormat:@"Encoded with Max %@", bundleVersion] UTF8String]);
		
		if(_writeSettingsToComment) {
			comment_add(&comments, &comments_length, NULL, [[self settings] UTF8String]);
		}
		
		op.packet		= (unsigned char *)comments;
		op.bytes		= comments_length;
		op.b_o_s		= 0;
		op.e_o_s		= 0;
		op.granulepos	= 0;
		op.packetno		= 1;
		
		ogg_stream_packetin(&os, &op);
		
		for(;;) {
			if(0 == ogg_stream_flush(&os, &og)) {
				break;	
			}
			
			currentBytesWritten = write(fd, og.header, og.header_len);
			if(-1 == currentBytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			bytesWritten += currentBytesWritten;
			
			currentBytesWritten = write(fd, og.body, og.body_len);
			if(-1 == currentBytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			bytesWritten += currentBytesWritten;
		}
		
		// Allocate the input buffer
		buflen								= 2 * frameSize;
		buf.mNumberBuffers					= 1;
		buf.mBuffers[0].mNumberChannels		= 2;
		buf.mBuffers[0].mDataByteSize		= buflen * sizeof(int16_t);
		buf.mBuffers[0].mData				= calloc(buflen, sizeof(int16_t));
		if(NULL == buf.mBuffers[0].mData) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		speex_bits_init(&bits);
		
		framesEncoded	= -lookahead;
		totalFrames		= 0;
		
		// Iteratively get the PCM data and encode it, one frame at a time
		while(NO == eos || totalFrames > framesEncoded) {
			
			// Read a single frame of PCM input
			frameCount	= buf.mBuffers[0].mDataByteSize / _inputASBD.mBytesPerFrame;
			err			= ExtAudioFileRead(extAudioFileRef, &frameCount, &buf);
			if(err != noErr) {
				@throw [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileRead failed", @"Exceptions", @"")
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			if(0 == frameCount) {
				eos = YES;
			}
			
			// Adjust for host endian-ness
			iter	= buf.mBuffers[0].mData;
			limit	= iter + (buf.mBuffers[0].mNumberChannels * frameCount);
			while(iter < limit) {
				*iter = OSSwapBigToHostInt16(*iter);
				++iter;
			}

			totalFrames += frameCount;			
			++frameID;
			
			if(2 == chan) {
				speex_encode_stereo_int(buf.mBuffers[0].mData, frameSize, &bits);
			}
			
			if(NULL != preprocess) {
				speex_preprocess(preprocess, buf.mBuffers[0].mData, NULL);
			}
			
			speex_encode_int(speexState, buf.mBuffers[0].mData, &bits);
			
			framesEncoded	+= frameSize;
			
			if(0 == (frameID + 1) % _framesPerPacket) {
				
				speex_bits_insert_terminator(&bits);
				nbBytes = speex_bits_write(&bits, cbits, 2000);
				speex_bits_reset(&bits);
				
				op.packet		= (unsigned char *)cbits;
				op.bytes		= nbBytes;
				op.b_o_s		= 0;
				op.e_o_s		= (eos && totalFrames <= framesEncoded) ? 1 : 0;
				op.granulepos	= (frameID + 1) * frameSize - lookahead;
				if(op.granulepos > totalFrames) {
					op.granulepos = totalFrames;
				}
				
				op.packetno		= 2 + frameID / _framesPerPacket;
				ogg_stream_packetin(&os, &op);
				
				// Write out pages
				for(;;) {
					
					if(0 == ogg_stream_pageout(&os, &og)) {
						break;
					}
					
					currentBytesWritten = write(fd, og.header, og.header_len);
					if(-1 == currentBytesWritten) {
						@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
					}
					bytesWritten += currentBytesWritten;
					
					currentBytesWritten = write(fd, og.body, og.body_len);
					if(-1 == currentBytesWritten) {
						@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
					}
					bytesWritten += currentBytesWritten;				
				}			
			}
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalFileFrames - framesToRead)/(double) totalFileFrames) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned int secondsRemaining = interval / ((double)(totalFileFrames - framesToRead)/(double) totalFileFrames) - interval;
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
		}
		
		// Finish up
		if(0 != (frameID + 1) % _framesPerPacket) {
			while(0 != (frameID + 1) % _framesPerPacket) {
				++frameID;
				speex_bits_pack(&bits, 15, 5);
			}
			
			nbBytes			= speex_bits_write(&bits, cbits, 2000);
			op.packet		= (unsigned char *)cbits;
			op.bytes		= nbBytes;
			op.b_o_s		= 0;
			op.e_o_s		= 1;
			op.granulepos	= (frameID + 1) * frameSize - lookahead;
			if(op.granulepos > totalFrames) {
				op.granulepos = totalFrames;
			}
			
			op.packetno = 2 + frameID / _framesPerPacket;
			ogg_stream_packetin(&os, &op);
		}
		
		// Flush all pages left to be written
		for(;;) {
			if(0 == ogg_stream_flush(&os, &og)) {
				break;	
			}
			
			currentBytesWritten = write(fd, og.header, og.header_len);
			if(-1 == currentBytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			bytesWritten += currentBytesWritten;
			
			currentBytesWritten = write(fd, og.body, og.body_len);
			if(-1 == currentBytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			bytesWritten += currentBytesWritten;
		}
	}

	@catch(StopException *exception) {
		[_delegate setStopped];
	}
	
	@catch(NSException *exception) {
		[_delegate setException:exception];
		[_delegate setStopped];
	}
	
	@finally {
		NSException *exception;
		
		// Close the input file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:NSLocalizedStringFromTable(@"ExtAudioFileDispose failed", @"Exceptions", @"")
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		if(-1 == close(fd)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Clean up
		free(comments);
		free(buf.mBuffers[0].mData);
		
		speex_encoder_destroy(speexState);
		speex_bits_destroy(&bits);
		ogg_stream_clear(&os);
	}

	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

- (NSString *) settings
{
	switch(_target) {
		case SPEEX_TARGET_QUALITY:
			return [NSString stringWithFormat:@"libSpeex settings: quality=%i complexity=%i%@%@%@%@", _quality, _complexity, (_vbrEnabled ? @" VBR" : @" "), (_abrEnabled ? @" ABR" : @" "), (_vadEnabled ? @" VAD" : @" "), (_dtxEnabled ? @" DTX" : @" ")];
			break;

		case SPEEX_TARGET_BITRATE:
			return [NSString stringWithFormat:@"libSpeex settings: bitrate=%i kpbs complexity=%i%@%@%@%@", _bitrate / 1000, _complexity, (_vbrEnabled ? @" VBR" : @" "), (_abrEnabled ? @" ABR" : @" "), (_vadEnabled ? @" VAD" : @" "), (_dtxEnabled ? @" DTX" : @" ")];
			break;
			
		default:
			return nil;
			break;
	}
}

@end
