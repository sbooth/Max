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

#import "ShortenConverter.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "CoreAudioException.h"

#include <unistd.h>		// lseek
#include <fcntl.h>		// open, write
#include <sys/stat.h>	// stat

@implementation ShortenConverter

- (oneway void) convertToFile:(NSString *)filename
{
	NSDate							*startTime			= [NSDate date];
	int								in_fd				= -1;
	ssize_t							totalBytes;
	int								samplesRead			= 0;
	long							samplesToRead		= 0;
	long							totalSamples		= 0;
	OSStatus						err;
	FSRef							ref;
	AudioFileID						audioFile;
	ExtAudioFileRef					extAudioFileRef;
	AudioBufferList					bufferList;
	UInt32							frameCount;
	long							bytesRead;
	char							*buffer				= NULL;
	unsigned long					iterations			= 0;
	AudioStreamBasicDescription		asbd;
	AudioStreamBasicDescription		inputASBD;
	
	// Tell our owner we are starting
	[_delegate setStartTime:startTime];	
	[_delegate setStarted];
	
	@try {
		// Open the input file
		in_fd = open([_inputFilename fileSystemRepresentation], O_RDONLY);
		if(-1 == in_fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Get input file information
		struct stat sourceStat;
		if(-1 == fstat(in_fd, &sourceStat)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to get information on the input file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		totalBytes		= sourceStat.st_size;
		bytesToRead		= totalBytes;

		// Get input file information		
		//totalSamples		= decompressor->GetInfo(APE_DECOMPRESS_TOTAL_BLOCKS);
		//samplesToRead		= totalSamples;
		//apeBlockSize		= decompressor->GetInfo(APE_INFO_BLOCK_ALIGN);
		
		//[self setSampleRate:decompressor->GetInfo(APE_INFO_SAMPLE_RATE)];
		//[self setBitsPerChannel:decompressor->GetInfo(APE_INFO_BITS_PER_SAMPLE)];
		//[self setChannelsPerFrame:decompressor->GetInfo(APE_INFO_CHANNELS)];
		
		// Open the output file
		err = FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &ref, NULL);
		if(noErr != err) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to locate the output file.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:filename, [NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"filename", @"errorCode", @"errorString", nil]]];
		}
		asbd = [self outputASBD];
		err = AudioFileInitialize(&ref, kAudioFileAIFFType, &asbd, 0, &audioFile);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileInitialize"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		err = ExtAudioFileWrapAudioFileID(audioFile, YES, &extAudioFileRef);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrapAudioFileID"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Shorten feeds us little-endian data, otherwise leave untouched
		inputASBD				= [self outputASBD];
		inputASBD.mFormatFlags	= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
		
		err = ExtAudioFileSetProperty(extAudioFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(inputASBD), &inputASBD);
		if(noErr != err) {
			@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileSetProperty"]
												  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Set up the AudioBufferList
		bufferList.mNumberBuffers					= 1;
		bufferList.mBuffers[0].mNumberChannels		= [self channelsPerFrame];
		
		// Allocate the buffer used for decompression
		buffer = (char *)calloc(512 * apeBlockSize, sizeof(char));
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		
		
		
		
		
		
		
		
		
		{
			/***********************/
			/* EXTRACT starts here */
			/***********************/
			
			int i, cmd;
			int internal_ftype;
			
			bitshift = 0;
			bytes_read = 0;
			
			
			/* read magic number */
#ifdef STRICT_FORMAT_COMPATABILITY
			if(FORMAT_VERSION < 2)
			{
				for(i = 0; i < strlen(magic); i++) {
					if(getc_exit(filei) != magic[i])
						usage_exit(1, "Bad magic number\n");
					bytes_read++;
				}
				
				/* get version number */
				version = getc_exit(filei);
				bytes_read++;
			}
			else
#endif /* STRICT_FORMAT_COMPATABILITY */
			{
				int nscan = 0;
				
				version = MAX_VERSION + 1;
				while(version > MAX_VERSION)
				{
					int byte = getc(filei);
					bytes_read++;
					if(byte == EOF) {
						if (WriteSeekTable) {
							unlink(SeekTableFilename);
							usage_exit(1, "-k, -s and -S can only be used on shorten files\n");
						}
						else
							usage_exit(1, "No magic number\n");
					}
					if(magic[nscan] != '\0' && byte == magic[nscan])
						nscan++;
					else if(magic[nscan] == '\0' && byte <= MAX_VERSION)
						version = byte;
					else
					{
						for(i = 0; i < nscan; i++)
							if (0 == WriteSeekTable) {
								putc_exit(magic[i], fileo);
							}
								if(byte == magic[0])
									nscan = 1;
							else
							{
								if (0 == WriteSeekTable) {
									putc_exit(byte, fileo);
								}
								nscan = 0;
							}
								version = MAX_VERSION + 1;
					}
				}
			}
			
			/* check version number */
			if(version > MAX_SUPPORTED_VERSION)
				update_exit(1, "can't decode version %d\n", version);
			
			/* set up the default nmean, ignoring the command line state */
			nmean = (version < 2) ? DEFAULT_V0NMEAN : DEFAULT_V2NMEAN;
			
			/* initialise the variable length file read for the compressed stream */
			var_get_init();
			
			/* initialise the fixed length file write for the uncompressed stream */
			fwrite_type_init();
			
			/* get the internal file type */
			internal_ftype = UINT_GET(TYPESIZE, filei);
			
			/* has the user requested a change in file type? */
			if(internal_ftype != ftype) {
				if(ftype == TYPE_EOF)
					ftype = internal_ftype;    /*  no problems here */
				else             /* check that the requested conversion is valid */
					if(internal_ftype == TYPE_AU1 || internal_ftype == TYPE_AU2 ||
					   internal_ftype == TYPE_AU3 || ftype == TYPE_AU1 ||ftype == TYPE_AU2 || ftype == TYPE_AU3)
						error_exit("Not able to perform requested output format conversion\n");
			}
			
			nchan = UINT_GET(CHANSIZE, filei);
			
			/* get blocksize if version > 0 */
			if(version > 0)
			{
				blocksize = UINT_GET((int) (log((double) DEFAULT_BLOCK_SIZE) / M_LN2),filei);
				maxnlpc = UINT_GET(LPCQSIZE, filei);
				nmean = UINT_GET(0, filei);
				nskip = UINT_GET(NSKIPSIZE, filei);
				for(i = 0; i < nskip; i++)
				{
					int byte = uvar_get(XBYTESIZE, filei);
					putc_exit(byte, fileo);
				}
			}
			else
				blocksize = DEFAULT_BLOCK_SIZE;
			
			nwrap = MAX(NWRAP, maxnlpc);
			
			/* grab some space for the input buffer */
			buffer  = long2d((ulong) nchan, (ulong) (blocksize + nwrap));
			offset  = long2d((ulong) nchan, (ulong) MAX(1, nmean));
			
			for(chan = 0; chan < nchan; chan++)
			{
				for(i = 0; i < nwrap; i++)
					buffer[chan][i] = 0;
				buffer[chan] += nwrap;
			}
			
			if(maxnlpc > 0)
				qlpc = (int*) pmalloc((ulong) (maxnlpc * sizeof(*qlpc)));
			
			if(version > 1)
				lpcqoffset = V2LPCQOFFSET;
			
			init_offset(offset, nchan, MAX(1, nmean), internal_ftype);
			
			if(WriteSeekTable && extract)
			{
				if(0 == Pass && (saw_s_op || saw_S_op))
					fprintf(stderr,"creating seek table file: '%s'\n",SeekTableFilename);
				else if (AppendSeekInfo)
					fprintf(stderr,"appending seek table to '%s'\n",filenamei);
				
				if((SeekTableFile = fopen(SeekTableFilename, writemode)) == NULL)
					usage_exit(1, "could not open seek table file '%s'\n", SeekTableFilename);
				
				fwrite(SeekTableHeader.data,1,SEEK_HEADER_SIZE,SeekTableFile);
			}
			
			/* get commands from file and execute them */
			chan = 0;
			while(1)
			{
				ReadingFunctionCode=TRUE;
				cmd = uvar_get(FNSIZE, filei);
				
				CBuf_0_Minus1=(slong)buffer[0][-1];
				CBuf_0_Minus2=(slong)buffer[0][-2];
				CBuf_0_Minus3=(slong)buffer[0][-3];
				Offset_0_0=(slong)offset[0][0];
				Offset_0_1=(slong)offset[0][1];
				Offset_0_2=(slong)offset[0][2];
				Offset_0_3=(slong)offset[0][3];
				
				if (nchan > 1)
				{
					CBuf_1_Minus1=(slong)buffer[1][-1];
					CBuf_1_Minus2=(slong)buffer[1][-2];
					CBuf_1_Minus3=(slong)buffer[1][-3];
					Offset_1_0=(slong)offset[1][0];
					Offset_1_1=(slong)offset[1][1];
					Offset_1_2=(slong)offset[1][2];
					Offset_1_3=(slong)offset[1][3];
				}
				else
				{
					CBuf_1_Minus1=0;
					CBuf_1_Minus2=0;
					CBuf_1_Minus3=0;
					Offset_1_0=0;
					Offset_1_1=0;
					Offset_1_2=0;
					Offset_1_3=0;
				}
				
				ReadingFunctionCode=FALSE;
				
				if(FN_QUIT==cmd)
					break;
				else
				{
#ifdef _WINDOWS
					/* Include processing to enable Windows program to abort */
					CheckWindowsAbort();
#endif
					switch(cmd)
					{
						case FN_ZERO:
						case FN_DIFF0:
						case FN_DIFF1:
						case FN_DIFF2:
						case FN_DIFF3:
						case FN_QLPC:
						{
							slong coffset, *cbuffer = buffer[chan];
							int resn = 0, nlpc, j;
							
							if(cmd != FN_ZERO)
							{
								resn = uvar_get(ENERGYSIZE, filei);
								/* this is a hack as version 0 differed in definition of var_get */
								if(version == 0)
									resn--;
							}
							
							/* find mean offset : N.B. this code duplicated */
							if(nmean == 0)
								coffset = offset[chan][0];
							else
							{
								slong sum = (version < 2) ? 0 : nmean / 2;
								for(i = 0; i < nmean; i++)
									sum += offset[chan][i];
								if(version < 2)
									coffset = sum / nmean;
								else
									coffset = ROUNDEDSHIFTDOWN(sum / nmean, bitshift);
							}
							
							switch(cmd)
							{
								case FN_ZERO:
									for(i = 0; i < blocksize; i++)
										cbuffer[i] = 0;
									break;
								case FN_DIFF0:
									for(i = 0; i < blocksize; i++)
										cbuffer[i] = var_get(resn, filei) + coffset;
									break;
								case FN_DIFF1:
									for(i = 0; i < blocksize; i++)
										cbuffer[i] = var_get(resn, filei) + cbuffer[i - 1];
									break;
								case FN_DIFF2:
									for(i = 0; i < blocksize; i++)
										cbuffer[i] = var_get(resn, filei) + (2 * cbuffer[i - 1] - cbuffer[i - 2]);
									break;
								case FN_DIFF3:
									for(i = 0; i < blocksize; i++)
										cbuffer[i] = var_get(resn, filei) + 3 * (cbuffer[i - 1] -  cbuffer[i - 2]) + cbuffer[i - 3];
									break;
								case FN_QLPC:
									nlpc = uvar_get(LPCQSIZE, filei);
									
									for(i = 0; i < nlpc; i++)
										qlpc[i] = var_get(LPCQUANT, filei);
										for(i = 0; i < nlpc; i++)
											cbuffer[i - nlpc] -= coffset;
											for(i = 0; i < blocksize; i++)
											{
												slong sum = lpcqoffset;
												
												for(j = 0; j < nlpc; j++)
													sum += qlpc[j] * cbuffer[i - j - 1];
												cbuffer[i] = var_get(resn, filei) + (sum >> LPCQUANT);
											}
												if(coffset != 0)
													for(i = 0; i < blocksize; i++)
														cbuffer[i] += coffset;
												break;
							}
							
							/* store mean value if appropriate : N.B. Duplicated code */
							if(nmean > 0)
							{
								slong sum = (version < 2) ? 0 : blocksize / 2;
								
								for(i = 0; i < blocksize; i++)
									sum += cbuffer[i];
								
								for(i = 1; i < nmean; i++)
									offset[chan][i - 1] = offset[chan][i];
								if(version < 2)
									offset[chan][nmean - 1] = sum / blocksize;
								else
									offset[chan][nmean - 1] = (sum / blocksize) << bitshift;
							}
							
							if(chan==0)
							{
								if(WriteSeekTable && WriteCount%100 == 0)
								{
									TSeekEntry SeekEntry;
									
									ulong_to_uchar_le(SeekEntry.data,SampleNumber);
									ulong_to_uchar_le(SeekEntry.data+4,SHNFilePosition);
									ulong_to_uchar_le(SeekEntry.data+8,SHNLastBufferReadPosition);
									ushort_to_uchar_le(SeekEntry.data+12,SHNByteGet);
									ushort_to_uchar_le(SeekEntry.data+14,SHNBufferOffset);
									ushort_to_uchar_le(SeekEntry.data+16,SHNBitPosition);
									ulong_to_uchar_le(SeekEntry.data+18,SHNGBuffer);
									ushort_to_uchar_le(SeekEntry.data+22,bitshift);
									
									long_to_uchar_le(SeekEntry.data+24,CBuf_0_Minus1);
									long_to_uchar_le(SeekEntry.data+28,CBuf_0_Minus2);
									long_to_uchar_le(SeekEntry.data+32,CBuf_0_Minus3);
									
									long_to_uchar_le(SeekEntry.data+36,CBuf_1_Minus1);
									long_to_uchar_le(SeekEntry.data+40,CBuf_1_Minus2);
									long_to_uchar_le(SeekEntry.data+44,CBuf_1_Minus3);
									
									long_to_uchar_le(SeekEntry.data+48,Offset_0_0);
									long_to_uchar_le(SeekEntry.data+52,Offset_0_1);
									long_to_uchar_le(SeekEntry.data+56,Offset_0_2);
									long_to_uchar_le(SeekEntry.data+60,Offset_0_3);
									
									long_to_uchar_le(SeekEntry.data+64,Offset_1_0);
									long_to_uchar_le(SeekEntry.data+68,Offset_1_1);
									long_to_uchar_le(SeekEntry.data+72,Offset_1_2);
									long_to_uchar_le(SeekEntry.data+76,Offset_1_3);
									
									fwrite(&SeekEntry,SEEK_ENTRY_SIZE,1,SeekTableFile);
								}
								WriteCount++;
							}
							
							/* do the wrap */
							for(i = -nwrap; i < 0; i++)
								cbuffer[i] = cbuffer[i + blocksize];
							
							fix_bitshift(cbuffer, blocksize, bitshift, internal_ftype);
							
							if(chan == nchan - 1)
							{
								SampleNumber+=blocksize;
								fwrite_type(buffer, ftype, nchan, blocksize, fileo);
							}
							chan = (chan + 1) % nchan;
							break;
						}
							
						case FN_BLOCKSIZE:
							blocksize = UINT_GET((int) (log((double) blocksize) / M_LN2), filei);
							break;
						case FN_BITSHIFT:
							bitshift = uvar_get(BITSHIFTSIZE, filei);
							break;
						case FN_VERBATIM:
						{
							int cklen = uvar_get(VERBATIM_CKSIZE_SIZE, filei);
							while (cklen--)
							{
								int ByteToWrite = uvar_get(VERBATIM_BYTE_SIZE, filei);
								if(WriteWaveFile)
									fputc(ByteToWrite,fileo);
							}
							break;
						}
							
						default:
							update_exit(1, "sanity check fails trying to decode function: %d\n",cmd);
					}
				}
			}
			
			/* wind up */
			var_get_quit();
			fwrite_type_quit();
			
			free((void *) buffer);
			free((void *) offset);
			if(maxnlpc > 0)
				free((void *) qlpc);
		}
		
		/* close the files if this function opened them */
		if(filei && filei != stdi)
			fclose(filei);
		if(fileo && fileo != stdo)
			fclose(fileo);

		
		
		
		
		
		
		
		
		
		
		for(;;) {
			
			// Decode the data
			result = decompressor->GetData(buffer, 512, &samplesRead);
			if(ERROR_SUCCESS != result) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Monkey's Audio invalid checksum.", @"Exceptions", @"") userInfo:nil];
			}
			bytesRead = samplesRead * apeBlockSize;
			
			// EOF?
			if(0 == bytesRead) {
				break;
			}
			
			bufferList.mBuffers[0].mData				= buffer;
			bufferList.mBuffers[0].mDataByteSize		= bytesRead;
			
			frameCount									= bytesRead / ([self channelsPerFrame] * ([self bitsPerChannel] / 8));
			
			// Write the data
			err = ExtAudioFileWrite(extAudioFileRef, frameCount, &bufferList);
			if(noErr != err) {
				@throw [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileWrite"]
													  userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Update status
			samplesToRead -= samplesRead;
			
			// Distributed Object calls are expensive, so only perform them every few iterations
			if(0 == iterations % MAX_DO_POLL_FREQUENCY) {
				
				// Check if we should stop, and if so throw an exception
				if([_delegate shouldStop]) {
					@throw [StopException exceptionWithReason:@"Stop requested by user" userInfo:nil];
				}
				
				// Update UI
				double percentComplete = ((double)(totalSamples - samplesToRead)/(double) totalSamples) * 100.0;
				NSTimeInterval interval = -1.0 * [startTime timeIntervalSinceNow];
				unsigned secondsRemaining = (unsigned) (interval / ((double)(totalSamples - samplesToRead)/(double) totalSamples) - interval);
				NSString *timeRemaining = [NSString stringWithFormat:@"%i:%02i", secondsRemaining / 60, secondsRemaining % 60];
				
				[_delegate updateProgress:percentComplete timeRemaining:timeRemaining];
			}
			
			++iterations;
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
		NSException						*exception;
		
		// Close the input file
		if(-1 == close(in_fd)) {
			exception = [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file.", @"Exceptions", @"") 
												userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}

		// Close the output file
		err = ExtAudioFileDispose(extAudioFileRef);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"ExtAudioFileDispose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}
		
		// Close the output file
		err = AudioFileClose(audioFile);
		if(noErr != err) {
			exception = [CoreAudioException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileClose"]
													   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithCString:GetMacOSStatusErrorString(err) encoding:NSASCIIStringEncoding], [NSString stringWithCString:GetMacOSStatusCommentString(err) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			NSLog(@"%@", exception);
		}		
		
		// Clean up
		delete decompressor;
		free(buffer);
		free(chars);
	}
	
	[_delegate setEndTime:[NSDate date]];
	[_delegate setCompleted];	
}

@end
