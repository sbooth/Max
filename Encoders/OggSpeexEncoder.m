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

#import "OggSpeexEncoder.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <speex/speex.h>
#include <speex/speex_header.h>
#include <speex/speex_stereo.h>
#include <speex/speex_callbacks.h>

#include <ogg/ogg.h>

#import "Decoder.h"
#import "RegionDecoder.h"

#import "StopException.h"

#import "UtilityFunctions.h"

#include <fcntl.h>		// open, write
#include <stdio.h>		// fopen, fclose

// My (semi-arbitrary) list of supported speex bitrates
static int sSpeexBitrates [13] = { 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28};

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
	int vendor_length = (int)strlen(vendor_string);
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
	int tag_len=(tag?(int)strlen(tag):0);
	int val_len=(int)strlen(val);
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

@interface OggSpeexEncoder (Private)
- (void)	parseSettings;
@end

@implementation OggSpeexEncoder

- (oneway void) encodeToFile:(NSString *) filename
{
	NSDate						*startTime									= [NSDate date];

	int							fd											= -1;
	int							result;
	
	void						*speexState									= NULL;
	const SpeexMode				*mode										= NULL;
	SpeexBits					bits;

	int							rate										= 44100;
	int							frameID										= -1;
	int							frameSize;
	char						*comments									= NULL;
	int							comments_length;
	SInt64						totalFrames;
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

	AudioBufferList				bufferList;
	ssize_t						bufferLen									= 0;
	UInt32						bufferByteSize								= 0;
	SInt64						totalFileFrames, framesToRead;
	UInt32						frameCount;

	int8_t						*buffer8									= NULL;
	int16_t						*buffer16									= NULL;
	int32_t						*buffer32									= NULL;
	float						*floatBuffer								= NULL;

//	int8_t						byteOne, byteTwo, byteThree;
	int32_t						constructedSample;
//	float						normalizedSample;

	unsigned					sample, wideSample;

	double						percentComplete;
	NSTimeInterval				interval;
	unsigned					secondsRemaining;	
	
	
	@try {
		bufferList.mBuffers[0].mData = NULL;

		// Parse the encoder settings
		[self parseSettings];

		// Tell our owner we are starting
		[[self delegate] setStartTime:startTime];	
		[[self delegate] setStarted:YES];
		
		// Setup the decoder
		id <DecoderMethods> decoder = nil;
		NSString *sourceFilename = [[[self delegate] taskInfo] inputFilenameAtInputFileIndex];
		
		// Create the appropriate kind of decoder
		if(nil != [[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"]) {
			SInt64 startingFrame = [[[[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"] valueForKey:@"startingFrame"] longLongValue];
			UInt32 frameCount = [[[[[[self delegate] taskInfo] settings] valueForKey:@"framesToConvert"] valueForKey:@"frameCount"] unsignedIntValue];
			decoder = [RegionDecoder decoderWithFilename:sourceFilename startingFrame:startingFrame frameCount:frameCount];
		}
		else
			decoder = [Decoder decoderWithFilename:sourceFilename];
		
		NSAssert(1 == [decoder pcmFormat].mChannelsPerFrame || 2 == [decoder pcmFormat].mChannelsPerFrame, NSLocalizedStringFromTable(@"Speex only supports one or two channel input.", @"Exceptions", @""));
		
		totalFrames			= [decoder totalFrames];
		framesToRead		= totalFrames;
		
		// Resample input if requested
/*		if(_resampleInput) {
			
			// Determine the desired sample rate
			switch(_mode) {
				case SPEEX_MODE_NARROWBAND:		rate = 8000;		break;
				case SPEEX_MODE_WIDEBAND:		rate = 16000;		break;
				case SPEEX_MODE_ULTRAWIDEBAND:	rate = 32000;		break;
					
				default:						
					@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex mode" userInfo:nil];
					break;
			}

			asbd				= [self inputASBD];
			asbd.mSampleRate	= (float)rate;
			
			err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
			NSAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty", UTCreateStringForOSType(err));
		}*/
		
		// Open the output file
		fd = open([filename fileSystemRepresentation], O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		NSAssert(-1 != fd, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));
		
		// Check if we should stop, and if so throw an exception
		if([[self delegate] shouldStop]) {
			@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
		}
		
		// Initialize ogg stream- use the current time as the stream id
		result = ogg_stream_init(&os, (int)arc4random());
		NSAssert(-1 != result, NSLocalizedStringFromTable(@"Unable to initialize the ogg stream.", @"Exceptions", @""));		
		
		// Setup encoder
		switch(_mode) {
			case SPEEX_MODE_NARROWBAND:		mode = speex_lib_get_mode(SPEEX_MODEID_NB);		break;
			case SPEEX_MODE_WIDEBAND:		mode = speex_lib_get_mode(SPEEX_MODEID_WB);		break;
			case SPEEX_MODE_ULTRAWIDEBAND:	mode = speex_lib_get_mode(SPEEX_MODEID_UWB);	break;
				
			default:						
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Unrecognized speex mode" userInfo:nil];
				break;
		}
		
		speex_init_header(&header, rate, 1, mode);
		
		header.frames_per_packet	= _framesPerOggPacket;
		header.vbr					= _vbrEnabled;
		header.nb_channels			= [decoder pcmFormat].mChannelsPerFrame;
		
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
//			lookahead	+= frameSize;
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
		
		if(_saveSettingsInComment) {
			comment_add(&comments, &comments_length, NULL, [[self settingsString] UTF8String]);
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
			NSAssert(-1 != currentBytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
			bytesWritten += currentBytesWritten;
			
			currentBytesWritten = write(fd, og.body, og.body_len);
			NSAssert(-1 != currentBytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
			bytesWritten += currentBytesWritten;
		}
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mData				= NULL;
		bufferList.mBuffers[0].mNumberChannels		= [decoder pcmFormat].mChannelsPerFrame;
		
		// Allocate the buffer that will hold the interleaved audio data
		bufferLen									= 2 * frameSize;
		switch([decoder pcmFormat].mBitsPerChannel) {
			
			case 8:
			case 24:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int8_t));
				bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen * sizeof(int8_t);
				break;
				
			case 16:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int16_t));
				bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen * sizeof(int16_t);
				break;
				
			case 32:
				bufferList.mBuffers[0].mData			= calloc(bufferLen, sizeof(int32_t));
				bufferList.mBuffers[0].mDataByteSize	= (UInt32)bufferLen * sizeof(int32_t);
				break;
				
			default:
				@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
				break;				
		}
		
		bufferByteSize = bufferList.mBuffers[0].mDataByteSize;
		NSAssert(NULL != bufferList.mBuffers[0].mData, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
		speex_bits_init(&bits);
		
		framesEncoded	= -lookahead;
		totalFrames		= 0;
		
		// Iteratively get the PCM data and encode it, one frame at a time
		while(NO == eos || totalFrames > framesEncoded) {
			
			// Set up the buffer parameters
			bufferList.mBuffers[0].mNumberChannels	= [decoder pcmFormat].mChannelsPerFrame;
			bufferList.mBuffers[0].mDataByteSize	= bufferByteSize;
			frameCount								= bufferList.mBuffers[0].mDataByteSize / [decoder pcmFormat].mBytesPerFrame;
			
			// Read a chunk of PCM input
			frameCount		= [decoder readAudio:&bufferList frameCount:frameCount];

			// We're finished if no frames were returned
			if(0 == frameCount) {
				eos = YES;
			}
			
			// Fill Speex buffer, converting to host endian byte order
			// Speex only supports 16-bit or floating point samples, so renormalize accordingly
			switch([decoder pcmFormat].mBitsPerChannel) {
				
				case 8:
					floatBuffer = calloc(frameCount, sizeof(float));
					NSAssert(NULL != floatBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
						
					buffer8 = bufferList.mBuffers[0].mData;
					for(sample = 0; sample < frameCount; ++sample) {
						floatBuffer[sample] = (float)(buffer8[sample] / 128.f);
					}
					break;
					
				case 16:
					buffer16 = bufferList.mBuffers[0].mData;
					for(sample = 0; sample < frameCount; ++sample) {
						buffer16[sample] = (int16_t)OSSwapBigToHostInt16(buffer16[sample]);
					}
					break;
					
				case 24:
					floatBuffer = calloc(frameCount, sizeof(float));
					NSAssert(NULL != floatBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
						
					buffer8 = bufferList.mBuffers[0].mData;
					for(wideSample = sample = 0; wideSample < frameCount && sample < bufferList.mBuffers[0].mDataByteSize; ++wideSample, ++sample) {
						constructedSample = (int8_t)*buffer8++; constructedSample <<= 8;
						constructedSample |= (uint8_t)*buffer8++; constructedSample <<= 8;
						constructedSample |= (uint8_t)*buffer8++;
						
						floatBuffer[wideSample] = (constructedSample / 8388608.);
					}
					break;

				case 32:
					floatBuffer = calloc(frameCount, sizeof(float));
					NSAssert(NULL != floatBuffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

					buffer32 = bufferList.mBuffers[0].mData;
					for(sample = 0; sample < frameCount; ++sample) {
						floatBuffer[sample] = (float)(OSSwapBigToHostInt32(buffer32[sample]) / 2147483648.f);
					}
					break;
					
				default:
					@throw [NSException exceptionWithName:@"IllegalInputException" reason:@"Sample size not supported" userInfo:nil]; 
					break;				
			}

			totalFrames += frameCount;			
			++frameID;
			
			switch([decoder pcmFormat].mBitsPerChannel) {

				case 8:
				case 24:
				case 32:
					if(2 == [decoder pcmFormat].mChannelsPerFrame) {
						speex_encode_stereo(floatBuffer, frameSize, &bits);
					}

					speex_encode(speexState, floatBuffer, &bits);

					free(floatBuffer);
					floatBuffer = NULL;
					break;
							
				case 16:
					if(2 == [decoder pcmFormat].mChannelsPerFrame) {
						speex_encode_stereo_int(bufferList.mBuffers[0].mData, frameSize, &bits);
					}
					
					speex_encode_int(speexState, bufferList.mBuffers[0].mData, &bits);
					break;
			}
			
			
			framesEncoded	+= frameSize;
			
			if(0 == (frameID + 1) % _framesPerOggPacket) {
				
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
				
				op.packetno		= 2 + frameID / _framesPerOggPacket;
				ogg_stream_packetin(&os, &op);
				
				// Write out pages
				for(;;) {
					
					if(0 == ogg_stream_pageout(&os, &og)) {
						break;
					}
					
					currentBytesWritten = write(fd, og.header, og.header_len);
					NSAssert(-1 != currentBytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
					bytesWritten += currentBytesWritten;
					
					currentBytesWritten = write(fd, og.body, og.body_len);
					NSAssert(-1 != currentBytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
					bytesWritten += currentBytesWritten;				
				}			
			}
			
			// Update status
			framesToRead -= frameCount;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([[self delegate] shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				percentComplete		= ((double)(totalFileFrames - framesToRead)/(double) totalFileFrames) * 100.0;
				interval			= -1.0 * [startTime timeIntervalSinceNow];
				secondsRemaining	= interval / ((double)(totalFileFrames - framesToRead)/(double) totalFileFrames) - interval;
				
				[[self delegate] updateProgress:percentComplete secondsRemaining:secondsRemaining];
			}
			
			++iterations;
		}
		
		// Finish up
		if(0 != (frameID + 1) % _framesPerOggPacket) {
			while(0 != (frameID + 1) % _framesPerOggPacket) {
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
			
			op.packetno = 2 + frameID / _framesPerOggPacket;
			ogg_stream_packetin(&os, &op);
		}
		
		// Flush all pages left to be written
		for(;;) {
			if(0 == ogg_stream_flush(&os, &og)) {
				break;	
			}
			
			currentBytesWritten = write(fd, og.header, og.header_len);
			NSAssert(-1 != currentBytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
			bytesWritten += currentBytesWritten;
			
			currentBytesWritten = write(fd, og.body, og.body_len);
			NSAssert(-1 != currentBytesWritten, NSLocalizedStringFromTable(@"Unable to write to the output file.", @"Exceptions", @""));
			bytesWritten += currentBytesWritten;
		}
	}

	@catch(StopException *exception) {
		[[self delegate] setStopped:YES];
	}
	
	@catch(NSException *exception) {
		[[self delegate] setException:exception];
		[[self delegate] setStopped:YES];
	}
	
	@finally {
		NSException *exception;
				
		// Close the output file
		if(-1 == close(fd)) {
			exception = [NSException exceptionWithName:@"IOException"
												reason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
											  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Clean up
		free(comments);
		free(bufferList.mBuffers[0].mData);
		free(floatBuffer);
		
		speex_encoder_destroy(speexState);
		speex_bits_destroy(&bits);
		ogg_stream_clear(&os);
	}
	
	[[self delegate] setEndTime:[NSDate date]];
	[[self delegate] setCompleted:YES];	
}

- (NSString *) settingsString
{
	switch(_target) {
		case SPEEX_TARGET_QUALITY:
			return [NSString stringWithFormat:@"Speex settings: quality=%i complexity=%i%@%@%@%@", _quality, _complexity, (_vbrEnabled ? @" VBR" : @" "), (_abrEnabled ? @" ABR" : @" "), (_vadEnabled ? @" VAD" : @" "), (_dtxEnabled ? @" DTX" : @" ")];
			break;

		case SPEEX_TARGET_BITRATE:
			return [NSString stringWithFormat:@"Speex settings: bitrate=%i kpbs complexity=%i%@%@%@%@", _bitrate / 1000, _complexity, (_vbrEnabled ? @" VBR" : @" "), (_abrEnabled ? @" ABR" : @" "), (_vadEnabled ? @" VAD" : @" "), (_dtxEnabled ? @" DTX" : @" ")];
			break;
			
		default:
			return nil;
			break;
	}
}

@end

@implementation OggSpeexEncoder (Private)

- (void) parseSettings
{
	NSDictionary *settings	= [[self delegate] encoderSettings];
	
	_mode				= [[settings objectForKey:@"mode"] intValue];
	
	_resampleInput		= [[settings objectForKey:@"resampleInput"] boolValue];
	
	_denoiseEnabled		= [[settings objectForKey:@"denoiseInput"] boolValue];
	_agcEnabled			= [[settings objectForKey:@"applyAGC"] boolValue];
	
	_target				= [[settings objectForKey:@"target"] intValue];
	
	_vbrEnabled			= [[settings objectForKey:@"enableVBR"] boolValue];
	_abrEnabled			= [[settings objectForKey:@"enableABR"] boolValue];
	
	_quality			= [[settings objectForKey:@"quality"] intValue];
	_bitrate			= sSpeexBitrates[[[settings objectForKey:@"bitrate"] intValue]] * 1000;
	
	_complexity			= [[settings objectForKey:@"complexity"] intValue];
	
	_vadEnabled			= [[settings objectForKey:@"enableVAD"] boolValue];
	_dtxEnabled			= [[settings objectForKey:@"enableDTX"] boolValue];
	
	_framesPerOggPacket	= [[settings objectForKey:@"framesPerPacket"] intValue];
	
	_saveSettingsInComment		= [[NSUserDefaults standardUserDefaults] boolForKey:@"saveSettingsInComment"];
}

@end
