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

#import "CoreAudioUtilities.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <CoreServices/CoreServices.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/AudioFormat.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioUnit/AudioCodec.h>

// Prototypes
static NSMutableArray *			GetCoreAudioEncodeFormats(void);
static BOOL						FormatIDIsValidForOutput(UInt32 formatID);
static NSMutableArray *			GetCoreAudioFileDataFormats(OSType filetype);
static NSMutableDictionary *	GetCoreAudioFileTypeInfo(OSType filetype);

#pragma mark Implementation

#if 0
static void 
DumpASBD(const AudioStreamBasicDescription *asbd)
{
	NSCParameterAssert(NULL != asbd);
	
	NSLog(@"mSampleRate         %f", asbd->mSampleRate);
	NSLog(@"mFormatID           %.4s", (const char *)(&asbd->mFormatID));
	NSLog(@"mFormatFlags        %u", asbd->mFormatFlags);
	NSLog(@"mBytesPerPacket     %u", asbd->mBytesPerPacket);
	NSLog(@"mFramesPerPacket    %u", asbd->mFramesPerPacket);
	NSLog(@"mBytesPerFrame      %u", asbd->mBytesPerFrame);
	NSLog(@"mChannelsPerFrame   %u", asbd->mChannelsPerFrame);
	NSLog(@"mBitsPerChannel     %u", asbd->mBitsPerChannel);
	NSLog(@"mReserved           %u", asbd->mReserved);
}
#endif

static NSArray *sEncodeFormats		= nil;
static NSArray *sWritableTypes		= nil;
static NSArray *sReadableTypes		= nil;
static NSArray *sAudioExtensions	= nil;

// Returns an array of valid formatIDs for encoding
static NSMutableArray *
GetCoreAudioEncodeFormats() 
{
	UInt32			*writableFormats	= NULL;
	NSMutableArray	*result				= nil;	
	
	@try {
		UInt32		size	= 0;
		OSStatus	err		= AudioFormatGetPropertyInfo(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size);

		NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFormatGetPropertyInfo", UTCreateStringForOSType(err));

		writableFormats = malloc(size);
		
		NSCAssert(NULL != writableFormats, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		unsigned numWritableFormats	= size / sizeof(UInt32);
		result = [NSMutableArray arrayWithCapacity:numWritableFormats];

		err = AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size, writableFormats);
		
		NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFormatGetProperty", UTCreateStringForOSType(err));

		unsigned i;
		for(i = 0; i < numWritableFormats; ++i)
			[result addObject:[NSNumber numberWithUnsignedLong:writableFormats[i]]];		
	}
		
	@finally {
		free(writableFormats);
	}
	
	return [[result retain] autorelease];
}

// Determine if the given formatID is valid for output
static BOOL
FormatIDIsValidForOutput(UInt32 formatID)
{
	@synchronized(sEncodeFormats) {
		if(nil == sEncodeFormats) {
			sEncodeFormats = [GetCoreAudioEncodeFormats() retain];
		}
	}

	return (kAudioFormatLinearPCM == formatID || [sEncodeFormats containsObject:[NSNumber numberWithUnsignedLong:formatID]]);
}

NSMutableArray *
GetCoreAudioFileDataFormats(OSType filetype)
{
	NSMutableArray					*result			= nil;
	OSType							*formatIDs		= NULL;
	AudioStreamBasicDescription		*variants		= NULL;
	AudioValueRange					*bitrates		= NULL;

	@try {
		UInt32 size;
		OSStatus err = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size);
		NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfoSize", UTCreateStringForOSType(err));

		unsigned numDataFormats	= size / sizeof(OSType);
		formatIDs		= malloc(size);
		NSCAssert(NULL != formatIDs, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size, formatIDs);
		NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

		result = [NSMutableArray arrayWithCapacity:numDataFormats];
		
		unsigned j;
		for(j = 0; j < numDataFormats; ++j) {
			AudioFileTypeAndFormatID	tf		= { filetype, formatIDs[j] };
			NSMutableDictionary			*dfi	= [NSMutableDictionary dictionaryWithCapacity:5];
			
			[dfi setObject:[NSNumber numberWithUnsignedLong:formatIDs[j]] forKey:@"formatID"];
			
			err = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size);
			NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfoSize", UTCreateStringForOSType(err));

			variants = malloc(size);
			NSCAssert(NULL != variants, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

			unsigned		numVariants		= size / sizeof(AudioStreamBasicDescription);
			NSMutableArray	*variantsA		= [NSMutableArray arrayWithCapacity:numVariants];

			err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size, variants);
			NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

			unsigned k;
			for(k = 0; k < numVariants; ++k) {
				
				AudioStreamBasicDescription desc = variants[k];
				NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:8];
		
				[d setObject:[NSNumber numberWithDouble:desc.mSampleRate] forKey:@"sampleRate"];
				[d setObject:[NSNumber numberWithUnsignedLong:desc.mFormatID] forKey:@"formatID"];
				[d setObject:[NSNumber numberWithUnsignedLong:desc.mFormatFlags] forKey:@"formatFlags"];
				[d setObject:[NSNumber numberWithUnsignedLong:desc.mBitsPerChannel] forKey:@"bitsPerChannel"];
				[d setObject:[NSNumber numberWithBool:FormatIDIsValidForOutput(desc.mFormatID)] forKey:@"writable"];
				
				// Interleaved 16-bit PCM audio
				AudioStreamBasicDescription inputASBD;
				inputASBD.mSampleRate			= 44100.f;
				inputASBD.mFormatID				= kAudioFormatLinearPCM;
				inputASBD.mFormatFlags			= kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
				inputASBD.mBytesPerPacket		= 4;
				inputASBD.mFramesPerPacket		= 1;
				inputASBD.mBytesPerFrame		= 4;
				inputASBD.mChannelsPerFrame		= 2;
				inputASBD.mBitsPerChannel		= 16;

				// In order to query what parameters an AudioCodec supports it's necessary to specify mChannelsPerFrame
				// I suppose it's possible this could lead to failure when encoding for files with more than two channels,
				// but stereo audio is the most common and it isn't realistic with the current app architecture to set
				// output formats based on the number of input channels.
				// Ideally this would be possible, and support custom channel maps, etc.
				desc.mChannelsPerFrame 			= 2;

				// Create a dummy converter to query
				AudioConverterRef dummyConverter;
				err = AudioConverterNew(&inputASBD, &desc, &dummyConverter);
				if(noErr == err) {					
					// Get the quality settings
					UInt32 defaultQuality;
					size = sizeof(defaultQuality);

					err = AudioConverterGetProperty(dummyConverter, kAudioConverterCodecQuality, &size, &defaultQuality);
					if(noErr == err)
						[d setObject:[NSNumber numberWithUnsignedLong:defaultQuality] forKey:@"quality"];

					// Get the available bitrates (CBR)
					UInt32 mode = kAudioCodecBitRateControlMode_Constant;
					err = AudioConverterSetProperty(dummyConverter, kAudioCodecPropertyBitRateControlMode, sizeof(mode), &mode);
					if(noErr == err) {
						[d setObject:[NSNumber numberWithBool:YES] forKey:@"cbrAvailable"];

						err = AudioConverterGetPropertyInfo(dummyConverter, kAudioConverterApplicableEncodeBitRates, &size, NULL);
						bitrates = malloc(size);
						NSCAssert(NULL != bitrates, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
						
						err = AudioConverterGetProperty(dummyConverter, kAudioConverterApplicableEncodeBitRates, &size, bitrates);
						if(noErr == err) {
							unsigned		bitrateCount	= size / sizeof(AudioValueRange);
							NSMutableArray	*bitratesA		= [NSMutableArray arrayWithCapacity:bitrateCount];
							
							unsigned n;
							for(n = 0; n < bitrateCount; ++n) {
								unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
//								unsigned long maxRate = (unsigned long) bitrates[n].mMaximum;
								if(0 != minRate)
									[bitratesA addObject:[NSNumber numberWithUnsignedLong: minRate / 1000]];
							}
							
							// For some reason some codec return {0.,0.} as bitrates multiple times (alac)
							if(0 != [bitratesA count]) {
								// FIXME: Replace use of "bitrates" throughout with "bitratesCBR"
								[d setObject:bitratesA forKey:@"bitrates"];
								[d setObject:bitratesA forKey:@"bitratesCBR"];
							}
							
							UInt32 defaultBitrate;
							size = sizeof(defaultBitrate);
							err = AudioConverterGetProperty(dummyConverter, kAudioConverterEncodeBitRate, &size, &defaultBitrate);

							if(noErr != err)
								NSLog(@"kAudioConverterEncodeBitRate failed: err = %@", UTCreateStringForOSType(err));

							[d setObject:[NSNumber numberWithUnsignedLong:defaultBitrate / 1000] forKey:@"bitrate"];
							
							free(bitrates);
							bitrates = NULL;
						}
					}

					// Get the available bitrates (VBR)
					mode = kAudioCodecBitRateControlMode_Variable;
					err = AudioConverterSetProperty(dummyConverter, kAudioCodecPropertyBitRateControlMode, sizeof(mode), &mode);
					if(noErr == err) {
						[d setObject:[NSNumber numberWithBool:YES] forKey:@"vbrAvailable"];

						err = AudioConverterGetPropertyInfo(dummyConverter, kAudioCodecPropertyApplicableBitRateRange, &size, NULL);
						bitrates = malloc(size);
						NSCAssert(NULL != bitrates, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
						
						// Determine which bitrates are supported for VBR (if any)
						err = AudioConverterGetProperty(dummyConverter, kAudioCodecPropertyApplicableBitRateRange, &size, bitrates);
						if(noErr == err) {
							unsigned		bitrateCount	= size / sizeof(AudioValueRange);
							NSMutableArray	*bitratesA		= [NSMutableArray arrayWithCapacity:bitrateCount];
							
							unsigned n;
							for(n = 0; n < bitrateCount; ++n) {
								unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
//								unsigned long maxRate = (unsigned long) bitrates[n].mMaximum;
								if(0 != minRate)
									[bitratesA addObject:[NSNumber numberWithUnsignedLong: minRate / 1000]];
							}
							
							// For some reason some codec return {0.,0.} as bitrates multiple times (alac)
							if(0 != [bitratesA count])
								[d setObject:bitratesA forKey:@"bitratesVBR"];
														
							free(bitrates);
							bitrates = NULL;
						}
					}

					// Get the available bitrates (ABR)
					mode = kAudioCodecBitRateControlMode_LongTermAverage;
					err = AudioConverterSetProperty(dummyConverter, kAudioCodecPropertyBitRateControlMode, sizeof(mode), &mode);
					if(noErr == err) {
						[d setObject:[NSNumber numberWithBool:YES] forKey:@"abrAvailable"];

						err = AudioConverterGetPropertyInfo(dummyConverter, kAudioCodecPropertyApplicableBitRateRange, &size, NULL);
						bitrates = malloc(size);
						NSCAssert(NULL != bitrates, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

						// Determine which bitrates are supported for ABR (if any)
						err = AudioConverterGetProperty(dummyConverter, kAudioCodecPropertyApplicableBitRateRange, &size, bitrates);
						if(noErr == err) {
							unsigned		bitrateCount	= size / sizeof(AudioValueRange);
							NSMutableArray	*bitratesA		= [NSMutableArray arrayWithCapacity:bitrateCount];

							unsigned n;
							for(n = 0; n < bitrateCount; ++n) {
								unsigned long minRate = (unsigned long) bitrates[n].mMinimum;
//								unsigned long maxRate = (unsigned long) bitrates[n].mMaximum;
								if(0 != minRate)
									[bitratesA addObject:[NSNumber numberWithUnsignedLong: minRate / 1000]];
							}

							// For some reason some codec return {0.,0.} as bitrates multiple times (alac)
							if(0 != [bitratesA count])
								[d setObject:bitratesA forKey:@"bitratesABR"];

							free(bitrates);
							bitrates = NULL;
						}
					}

					// Cleanup
					err = AudioConverterDispose(dummyConverter);
					NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioConverterDispose", UTCreateStringForOSType(err));
				}

				NSString *description = nil;
				size = sizeof(description);

				// Workaround a bug in Leopard where mChannelsPerFrame comes back as 1 for M4A/AAC
				desc.mChannelsPerFrame = 0;
				
				err = AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &desc, &size, &description);
				if(noErr != err)
					description = NSLocalizedStringFromTable(@"Unknown", @"General", @"");
				
				[d setObject:description forKey:@"description"];
							
				[variantsA addObject:d];
			}			
			
			[result addObjectsFromArray:variantsA];
			free(variants);
			variants = NULL;
		}
	}
	
	@finally {
		free(bitrates);
		free(variants);
		free(formatIDs);
	}

	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	[result sortUsingDescriptors:[NSArray arrayWithObject:sd]];
	
	return [[result retain] autorelease];
}

static NSMutableDictionary *
GetCoreAudioFileTypeInfo(OSType filetype)
{
	NSMutableDictionary		*result				= [NSMutableDictionary dictionaryWithCapacity:2];
	NSString				*fileTypeName		= nil;
	NSArray					*extensions			= nil;
	
	// file type name
	UInt32		size	= sizeof(fileTypeName);
	OSStatus	err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, sizeof(UInt32), &filetype, &size, &fileTypeName);
	
	NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

	if(fileTypeName)
		[result setObject:fileTypeName forKey:@"fileTypeName"];
	
	// file extensions
	size	= sizeof(extensions);
	err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ExtensionsForType, sizeof(OSType), &filetype, &size, &extensions);

	NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

	if(extensions)
		[result setObject:extensions forKey:@"extensionsForType"];
	
	[result setObject:GetCoreAudioFileDataFormats(filetype) forKey:@"dataFormats"];
	
	return [[result retain] autorelease];
}

// Return an array of information on valid formats for output
NSArray *
GetCoreAudioWritableTypes()
{
	UInt32 *fileFormats = NULL;

	@synchronized(sWritableTypes) {
		if(nil == sWritableTypes) {
			@try {
				UInt32		size;
				OSStatus	err		= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size);

				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));

				fileFormats = malloc(size);
				
				NSCAssert(NULL != fileFormats, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

				unsigned		numFileFormats		= size / sizeof(UInt32);
				NSMutableArray	*result				= [NSMutableArray arrayWithCapacity:numFileFormats];

				err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size, fileFormats);
				
				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
				
				unsigned i;
				for(i = 0; i < numFileFormats; ++i) {
					NSMutableDictionary		*d					= [NSMutableDictionary dictionaryWithCapacity:3];
					NSMutableArray			*dataFormats;
					NSMutableIndexSet		*indexesToRemove	= [NSMutableIndexSet indexSet];
					BOOL					writable			= NO;
					NSUInteger				dataFormatsCount;
					
					[d setObject:[NSNumber numberWithUnsignedLong:fileFormats[i]] forKey:@"fileType"];
					[d addEntriesFromDictionary:GetCoreAudioFileTypeInfo(fileFormats[i])];
					
					dataFormats			= [d valueForKey:@"dataFormats"];
					dataFormatsCount	= [dataFormats count];
					
					// Iterate through dataFormats and remove non-writable ones if desired
					unsigned j;
					for(j = 0; j < dataFormatsCount; ++j) {
						if(NO == [[[dataFormats objectAtIndex:j] valueForKey:@"writable"] boolValue])
							[indexesToRemove addIndex:j];
						else
							writable = YES;
					}
					
					[dataFormats removeObjectsAtIndexes:indexesToRemove];
					
					// Only add this file type if one of more of the dataFormats are writable
					if(writable)
						[result addObject:d];		
				}
				
				NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"fileTypeName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];

				sWritableTypes	= [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];
				
				[sWritableTypes retain];
			}
			
			@finally {
				free(fileFormats);
			}
		}
	}
	
	return sWritableTypes;
}

// Return an array of information on valid formats for input
NSArray *
GetCoreAudioReadableTypes()
{
	UInt32 *fileFormats = NULL;
	
	@synchronized(sReadableTypes) {
		if(nil == sReadableTypes) {
			@try {
				UInt32		size;
				OSStatus	err		= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_ReadableTypes, 0, NULL, &size);

				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfoSize", UTCreateStringForOSType(err));

				fileFormats = malloc(size);
				
				NSCAssert(NULL != fileFormats, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

				unsigned		numFileFormats		= size / sizeof(UInt32);
				NSMutableArray	*result				= [NSMutableArray arrayWithCapacity:numFileFormats];
				
				err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ReadableTypes, 0, NULL, &size, fileFormats);
				
				NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
				
				unsigned i;
				for(i = 0; i < numFileFormats; ++i) {
					NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:3];
					
					[d setObject:[NSNumber numberWithUnsignedLong:fileFormats[i]] forKey:@"fileType"];
					[d addEntriesFromDictionary:GetCoreAudioFileTypeInfo(fileFormats[i])];
					
					[result addObject:d];		
				}
				
				NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"fileTypeName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];

				sReadableTypes = [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:sd]];

				[sReadableTypes retain];
			}
					
			@finally {
				free(fileFormats);
			}
		}		
	}

	return sReadableTypes;
}

// Return an array of valid audio file extensions recognized by Core Audio
NSArray *
GetCoreAudioExtensions()
{
	@synchronized(sAudioExtensions) {
		if(nil == sAudioExtensions) {
			UInt32		size	= sizeof(sAudioExtensions);
			OSStatus	err		= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllExtensions, 0, NULL, &size, &sAudioExtensions);

			NSCAssert2(noErr == err, NSLocalizedStringFromTable(@"The call to %@ failed.", @"Exceptions", @""), @"AudioFileGetGlobalInfo", UTCreateStringForOSType(err));
			
			[sAudioExtensions retain];
		}
	}
	
	return sAudioExtensions;
}

// Set the format name
NSString * 
GetCoreAudioOutputFormatName(AudioFileTypeID fileType, UInt32 formatID, UInt32 formatFlags)
{
	AudioStreamBasicDescription		asbd;
	NSString						*fileFormat				= nil;
	NSString						*audioFormat			= nil;
	NSString						*name					= nil;
	
	// Determine the name of the file (container) type
	UInt32		specifierSize	= sizeof(fileType);
	UInt32		dataSize		= sizeof(fileFormat);
	OSStatus	result			= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, specifierSize, &fileType, &dataSize, &fileFormat);
	
	NSCAssert1(noErr == result, @"AudioFileGetGlobalInfo failed: %@", UTCreateStringForOSType(result));
	
	// Determine the name of the format contained in the file (if specified)
	if(0 != formatID) {
		bzero(&asbd, sizeof(AudioStreamBasicDescription));
		
		asbd.mFormatID			= formatID;
		asbd.mFormatFlags		= formatFlags;
		
		specifierSize			= sizeof(audioFormat);
		result					= AudioFormatGetProperty(kAudioFormatProperty_FormatName, sizeof(AudioStreamBasicDescription), &asbd, &specifierSize, &audioFormat);
		
		NSCAssert1(noErr == result, @"AudioFormatGetProperty failed: %@", UTCreateStringForOSType(result));
	}
	
	name = [NSString stringWithFormat:@"%@ (%@)", [fileFormat autorelease], [audioFormat autorelease]];
	
	return [[name retain] autorelease];
}
