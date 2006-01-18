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
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "MissingResourceException.h"
#import "SpeexException.h"
#import "CoreAudioException.h"

#import "UtilityFunctions.h"

#include "speex/speex.h"
#include "speex/speex_header.h"
#include "speex/speex_stereo.h"
#include "speex/speex_preprocess.h"
#include "ogg/ogg.h"

#include "sndfile.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose
#include <sys/stat.h>	// stat
#include <paths.h>		//_PATH_TMP
#include <unistd.h>		// mkstemp, unlink

#define TEMPFILE_PATTERN	"MaxXXXXXX.raw"

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

static void comment_init(char **comments, int *length, char *vendor_string)
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

static void comment_add(char **comments, int *length, char *tag, char *val)
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
			@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to load %@", @"Exceptions", @""), @"SpeexDefaults.plist"] userInfo:nil];
		}
		speexDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:speexDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:speexDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) initWithPCMFilename:(NSString *)pcmFilename
{
	if((self = [super initWithPCMFilename:pcmFilename])) {
		
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
			
		// Setup downsampled file, if needed (do it here to avoid multithreaded issues)
		if(_resampleInput) {
			char				*path			= NULL;
			const char			*tmpDir;
			ssize_t				tmpDirLen;
			ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
				tmpDir = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] stringByAppendingString:@"/"] UTF8String];
			}
			else {
				tmpDir = _PATH_TMP;
			}
			
			tmpDirLen	= strlen(tmpDir);
			path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
			if(NULL == path) {
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			memcpy(path, tmpDir, tmpDirLen);
			memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
			path[tmpDirLen + patternLen] = '\0';
			
			_resampledOut = mkstemps(path, 4);
			if(-1 == _resampledOut) {
				@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			
			_resampledFilename = [[NSString stringWithUTF8String:path] retain];
			
			free(path);
		}
			
		return self;
	}
	return nil;
}

- (void) dealloc
{
	// Delete resampled temporary file
	if(_resampleInput) {
		if(-1 == unlink([_resampledFilename UTF8String])) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete temporary file '%@' (%i:%s)", _resampledFilename, errno, strerror(errno)] userInfo:nil];
		}			

		[_resampledFilename release];
	}

	[super dealloc];
}

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime									= [NSDate date];

	void						*speexState;
	const SpeexMode				*mode;
	SpeexPreprocessState		*preprocess;
	SpeexBits					bits;

	int							rate;
	int							chan										= 2;
	int							frameID										= -1;
	int							frameSize;
	char						*comments;
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

	ssize_t						framesRead;
	ssize_t						bytesRead									= 0;
	ssize_t						currentBytesWritten							= 0;
	ssize_t						bytesWritten								= 0;
	ssize_t						bytesToRead									= 0;
	ssize_t						totalBytes									= 0;

	unsigned long				iterations									= 0;
	   
   
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];

	// Downsample input if requested using libsndfile
	if(_resampleInput) {
		SNDFILE						*inSF;
		SF_INFO						info;
		SNDFILE						*outSF				= NULL;
		const char					*string				= NULL;
		int							i;
		int							err					= 0 ;
		int							bufferLen			= 1024;
		int							*intBuffer			= NULL;
		double						*doubleBuffer		= NULL;
		double						maxSignal;
		int							frameCount;
		int							readCount;
		
		// Open the input file
		info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
		info.samplerate		= 44100;
		info.channels		= 2;
		
		inSF = sf_open([_pcmFilename UTF8String], SFM_READ, &info);
		if(NULL == inSF) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input sndfile (%i:%s)", sf_error(NULL), sf_strerror(NULL)] userInfo:nil];
		}
			
		// Determine the desired sample rate
		switch(_mode) {
			case SPEEX_MODE_NARROWBAND:		rate = 8000;		break;
			case SPEEX_MODE_WIDEBAND:		rate = 16000;		break;
			case SPEEX_MODE_ULTRAWIDEBAND:	rate = 32000;		break;
				
			default:						
				[_delegate setStopped];
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex mode" userInfo:nil];
				break;
		}
				
		// Setup downsampled output file
		info.format			= SF_FORMAT_RAW | SF_FORMAT_PCM_16;
		info.samplerate		= rate;
		info.channels		= 2;
		outSF				= sf_open_fd(_resampledOut, SFM_WRITE, &info, 1);
		if(NULL == outSF) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create output sndfile (%i:%s)", sf_error(NULL), sf_strerror(NULL)] userInfo:nil];
		}
		
		// Copy metadata
		for(i = SF_STR_FIRST; i <= SF_STR_LAST; ++i) {
			string = sf_get_string(inSF, i);
			if(NULL != string) {
				err = sf_set_string(outSF, i, string);
			}
		}
		
		// Copy audio data
		if(((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_DOUBLE) || ((info.format & SF_FORMAT_SUBMASK) == SF_FORMAT_FLOAT)) {
			
			doubleBuffer = (double *)malloc(bufferLen * sizeof(double));
			if(NULL == doubleBuffer) {
				[_delegate setStopped];
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			
			frameCount		= bufferLen / info.channels ;
			readCount		= frameCount ;
			
			sf_command(inSF, SFC_CALC_SIGNAL_MAX, &maxSignal, sizeof(maxSignal)) ;
			
			if(maxSignal < 1.0) {	
				while(readCount > 0) {
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						[_delegate setStopped];
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_double(inSF, doubleBuffer, frameCount) ;
					sf_writef_double(outSF, doubleBuffer, readCount) ;
					
					++iterations;
				}
			}
			// Renormalize output
			else {	
				sf_command(inSF, SFC_SET_NORM_DOUBLE, NULL, SF_FALSE);
				
				while(0 < readCount) {
					// Check if we should stop, and if so throw an exception
					if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
						[_delegate setStopped];
						@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
					}
					
					readCount = sf_readf_double(inSF, doubleBuffer, frameCount);
					for(i = 0 ; i < readCount * info.channels; ++i) {
						doubleBuffer[i] /= maxSignal;
					}
					
					sf_writef_double(outSF, doubleBuffer, readCount);
					
					++iterations;
				}
			}
			
			free(doubleBuffer);
		}
		else {
			intBuffer = (int *)malloc(bufferLen * sizeof(int));
			if(NULL == intBuffer) {
				[_delegate setStopped];
				@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
			}
			
			frameCount		= bufferLen / info.channels;
			readCount		= frameCount;
			
			while(0 < readCount) {	
				// Check if we should stop, and if so throw an exception
				if(0 == iterations % MAX_DO_POLL_FREQUENCY && [_delegate shouldStop]) {
					[_delegate setStopped];
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				readCount = sf_readf_int(inSF, intBuffer, frameCount);
				sf_writef_int(outSF, intBuffer, readCount);
				
				++iterations;
			}
			
			free(intBuffer);
		}
		
		// Clean up sndfile
		sf_close(inSF);
		sf_close(outSF);	// Also closes _resampledOut
				
		// Open the new, downsampled input file
		_pcm = open([_resampledFilename UTF8String], O_RDONLY);
		if(-1 == _pcm) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
	}
	else {
		rate = 44100;

		// Open the input file
		_pcm = open([_pcmFilename UTF8String], O_RDONLY);
		if(-1 == _pcm) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to open input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
	}
	
	// Get input file information
	struct stat sourceStat;
	if(-1 == fstat(_pcm, &sourceStat)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to stat input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	totalBytes		= sourceStat.st_size;
	bytesToRead		= totalBytes;

	// Create the output file
	_out = open([filename UTF8String], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if(-1 == _out) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to create the output file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	// Check if we should stop, and if so throw an exception
	if([_delegate shouldStop]) {
		[_delegate setStopped];
		@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
	}

	// Initialize ogg stream- use the current time as the stream id
	srand(time(NULL));
	if(-1 == ogg_stream_init(&os, rand())) {
		[_delegate setStopped];
		@throw [SpeexException exceptionWithReason:@"Unable to initialize ogg stream." userInfo:nil];
	}


	// Setup encoder from user defaults
	switch(_mode) {
		case SPEEX_MODE_NARROWBAND:		mode = speex_lib_get_mode(SPEEX_MODEID_NB);		break;
		case SPEEX_MODE_WIDEBAND:		mode = speex_lib_get_mode(SPEEX_MODEID_WB);		break;
		case SPEEX_MODE_ULTRAWIDEBAND:	mode = speex_lib_get_mode(SPEEX_MODEID_UWB);	break;

		default:						
			[_delegate setStopped];
			@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex mode" userInfo:nil];
			break;
	}
	
	speex_init_header(&header, rate, 1, mode);
	
	header.frames_per_packet	= _framesPerPacket;
	header.vbr					= _vbrEnabled;
	header.nb_channels			= chan;
		
	// Setup the encoder
	speexState = speex_encoder_init(mode);
		
	speex_encoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
	speex_encoder_ctl(speexState, SPEEX_SET_COMPLEXITY, &_complexity);
	speex_encoder_ctl(speexState, SPEEX_SET_SAMPLING_RATE, &rate);

	if(SPEEX_TARGET_QUALITY == _target) {
		if(_vbrEnabled) {
			speex_encoder_ctl(speexState, SPEEX_SET_VBR_QUALITY, &_quality);
		}
		else {
			speex_encoder_ctl(speexState, SPEEX_SET_QUALITY, &_quality);
		}
	}
	else if(SPEEX_TARGET_BITRATE == _target) {
		speex_encoder_ctl(speexState, SPEEX_SET_BITRATE, &_bitrate);
	}
	else {
		[_delegate setStopped];
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex target" userInfo:nil];
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

	bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	
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
	free(comments);

	for(;;) {
		if(0 == ogg_stream_flush(&os, &og)) {
			break;	
		}
		
		currentBytesWritten = write(_out, og.header, og.header_len);
		if(-1 == currentBytesWritten) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		bytesWritten += currentBytesWritten;
		
		currentBytesWritten = write(_out, og.body, og.body_len);
		if(-1 == currentBytesWritten) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		bytesWritten += currentBytesWritten;
	}
	
	// Allocate the buffer (hardcoded for 16-bit stereo input)
	_buflen			= 2 * frameSize;
	_buf			= (int16_t *) calloc(_buflen, sizeof(int16_t));
	if(NULL == _buf) {
		[_delegate setStopped];
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	speex_bits_init(&bits);

	framesEncoded	= -lookahead;
	totalFrames		= 0;
	
	// Iteratively get the PCM data and encode it, one frame at a time
	while(NO == eos || totalFrames > framesEncoded) {
		
		// Read a single frame of PCM input
		bytesRead = read(_pcm, _buf, (bytesToRead > 2 * _buflen ? 2 * _buflen : bytesToRead));
		if(-1 == bytesRead) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to read from input file. (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		else if(0 == bytesRead) {
			eos = YES;
		}
		
		framesRead		= bytesRead / 4;
		totalFrames		+= framesRead;
		
		++frameID;
		
		if(2 == chan) {
			speex_encode_stereo_int(_buf, frameSize, &bits);
		}
		
		if(NULL != preprocess) {
			speex_preprocess(preprocess, _buf, NULL);
		}

		speex_encode_int(speexState, _buf, &bits);
		
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
				
				currentBytesWritten = write(_out, og.header, og.header_len);
				if(-1 == currentBytesWritten) {
					[_delegate setStopped];
					@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
				}
				bytesWritten += currentBytesWritten;
				
				currentBytesWritten = write(_out, og.body, og.body_len);
				if(-1 == currentBytesWritten) {
					[_delegate setStopped];
					@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
				}
				bytesWritten += currentBytesWritten;				
			}			
		}

		// Update status
		bytesToRead -= bytesRead;
		
		// Distributed Object calls are expensive, so only perform them every few iterations
		if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
			
			// Check if we should stop, and if so throw an exception
			if([_delegate shouldStop]) {
				[_delegate setStopped];
				@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
			}
			
			// Update UI
			double percentComplete = ((double)(totalBytes - bytesToRead)/(double) totalBytes) * 100.0;
			NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
			unsigned int secondsRemaining = interval / ((double)(totalBytes - bytesToRead)/(double) totalBytes) - interval;
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
		
		currentBytesWritten = write(_out, og.header, og.header_len);
		if(-1 == currentBytesWritten) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		bytesWritten += currentBytesWritten;
		
		currentBytesWritten = write(_out, og.body, og.body_len);
		if(-1 == currentBytesWritten) {
			[_delegate setStopped];
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to write to output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
		}
		bytesWritten += currentBytesWritten;
	}

	// Close the input file
	if(-1 == close(_pcm)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close input file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}
	
	// Close the output file
	if(-1 == close(_out)) {
		[_delegate setStopped];
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to close output file (%i:%s) [%s:%i]", errno, strerror(errno), __FILE__, __LINE__] userInfo:nil];
	}

	// Clean up
	speex_encoder_destroy(speexState);
	speex_bits_destroy(&bits);
	ogg_stream_clear(&os);

	free(_buf);

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
