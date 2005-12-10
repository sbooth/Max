/*
 *  $Id: UtilityFunctions.h 175 2005-11-25 04:56:46Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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
#import "MallocException.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <CoreServices/CoreServices.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/AudioFormat.h>

// Prototypes
static NSMutableArray *			getCoreAudioEncodeFormats();
static BOOL						formatIDValidForOutput(UInt32 formatID);
static NSMutableArray *			getCoreAudioFileDataFormats(OSType filetype);
static NSMutableDictionary *	getCoreAudioFileTypeInfo(OSType filetype);

#pragma mark Implementation

// Returns an array of valid formatIDs for encoding
static NSMutableArray *
getCoreAudioEncodeFormats() 
{
	OSStatus			err;
	UInt32				size;
	UInt32				*writableFormats;
	int					numWritableFormats, i;
	NSMutableArray		*result;
	
	err					= AudioFormatGetPropertyInfo(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size);
	writableFormats		= malloc(size);
	if(NULL == writableFormats) {
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	numWritableFormats	= size / sizeof(UInt32);
	result				= [NSMutableArray arrayWithCapacity:numWritableFormats];
	err					= AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size, writableFormats);
	
	for(i = 0; i < numWritableFormats; ++i) {
		[result addObject:[NSNumber numberWithUnsignedLong:writableFormats[i]]];		
	}
	
	free(writableFormats);
	return [[result retain] autorelease];
}

// Determine if the given formatID is valid for output
static BOOL
formatIDValidForOutput(UInt32 formatID)
{
	static NSArray *sEncodeFormats = nil;
	
	@synchronized(sEncodeFormats) {
		if(nil == sEncodeFormats) {
			sEncodeFormats = getCoreAudioEncodeFormats();
		}
	}
	
	return (kAudioFormatLinearPCM == formatID || [sEncodeFormats containsObject:[NSNumber numberWithUnsignedLong:formatID]]);
	
}

static NSMutableArray *
getCoreAudioFileDataFormats(OSType filetype)
{
	OSStatus				err;
	UInt32					size;
	NSMutableArray			*result;
	int						numDataFormats, j, k;
	OSType					*formatIDs;
	BOOL					writable;
	
	err				= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size);
	numDataFormats	= size / sizeof(OSType);
	formatIDs		= malloc(size);
	if(NULL == formatIDs) {
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	err				= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size, formatIDs);
	result			= [NSMutableArray arrayWithCapacity:numDataFormats];
	
	for(j = 0; j < numDataFormats; ++j) {
		int								numVariants;
		NSMutableArray					*variantsA;
		AudioStreamBasicDescription		*variants;
		AudioFileTypeAndFormatID		tf				= { filetype, formatIDs[j] };
		NSMutableDictionary				*dfi			= [NSMutableDictionary dictionaryWithCapacity:5];
		
		[dfi setValue:[NSNumber numberWithUnsignedLong:formatIDs[j]] forKey:@"formatID"];
		
		err				= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size);
		variants		= malloc(size);
		if(NULL == variants) {
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
		}
		numVariants		= size / sizeof(AudioStreamBasicDescription);
		variantsA		= [NSMutableArray arrayWithCapacity:numVariants];
		err				= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size, variants);
		
		for(k = 0; k < numVariants; ++k) {
			
			NSString						*description;
			AudioStreamBasicDescription		*desc			= &variants[k];
			NSMutableDictionary				*d				= [NSMutableDictionary dictionaryWithCapacity:8];
			
			writable										= formatIDValidForOutput(desc->mFormatID);
			
			[d setValue:[NSNumber numberWithDouble:desc->mSampleRate] forKey:@"sampleRate"];
			[d setValue:[NSNumber numberWithUnsignedLong:desc->mFormatID] forKey:@"formatID"];
			[d setValue:[NSNumber numberWithUnsignedLong:desc->mFormatFlags] forKey:@"formatFlags"];
			[d setValue:[NSNumber numberWithUnsignedLong:desc->mBitsPerChannel] forKey:@"bitsPerChannel"];
			[d setValue:[NSNumber numberWithBool:writable] forKey:@"writable"];
			
			switch(desc->mFormatID) {
				case kAudioFormatLinearPCM:
					if(! (desc->mFormatFlags & kAudioFormatFlagIsFloat)) {
						description = [NSString stringWithFormat:@"%@ %i bit PCM", (desc->mFormatFlags && kAudioFormatFlagIsSignedInteger ? @"Signed" : @"Unsigned"), desc->mBitsPerChannel];
					}
					else {
						description = [NSString stringWithFormat:@"%i bit float", desc->mBitsPerChannel];
					}
					break;
					
					
				case kAudioFormatMPEG4AAC:
					switch(desc->mFormatFlags) {
						case kMPEG4Object_AAC_Main:			description = @"MPEG-4 AAC (Main)";				break;
						case kMPEG4Object_AAC_LC:			description = @"MPEG-4 AAC (LC)";				break;
						case kMPEG4Object_AAC_SSR:			description = @"MPEG-4 AAC (SSR)";				break;
						case kMPEG4Object_AAC_LTP:			description = @"MPEG-4 AAC (LTP)";				break;
						case kMPEG4Object_AAC_SBR:			description = @"MPEG-4 AAC (SBR)";				break;
						case kMPEG4Object_AAC_Scalable:		description = @"MPEG-4 AAC (Scalable)";			break;
						default:							description = @"MPEG-4 AAC";					break;
					}
					break;
					
					// Ignore flags for these
				case kAudioFormat60958AC3:					description = @"AC-3 SPDIF";					break;
				case kAudioFormatMPEG4CELP:					description = @"MPEG-4 CELP";					break;
				case kAudioFormatMPEG4HVXC:					description = @"MPEG-4 HVXC";					break;
				case kAudioFormatMPEG4TwinVQ:				description = @"MPEG-4 TwinVQ";					break;
					
					// Formats with no flags
				case kAudioFormatAC3:						description = @"AC-3";							break;
				case kAudioFormatAppleIMA4:					description = @"IMA 4:1 ADPCM";					break;
				case kAudioFormatMACE3:						description = @"MACE 3:1";						break;
				case kAudioFormatMACE6:						description = @"MACE 6:1";						break;
				case kAudioFormatULaw:						description = @"uLaw 2:1";						break;
				case kAudioFormatALaw:						description = @"aLaw 2:1";						break;
				case kAudioFormatQDesign:					description = @"QDesign Music";					break;
				case kAudioFormatQDesign2:					description = @"QDesign2 Music";				break;
				case kAudioFormatQUALCOMM:					description = @"QUALCOMM PureVoice";			break;
				case kAudioFormatMPEGLayer1:				description = @"MPEG Layer I";					break;
				case kAudioFormatMPEGLayer2:				description = @"MPEG Layer II";					break;
				case kAudioFormatMPEGLayer3:				description = @"MPEG Layer III";				break;
				case kAudioFormatDVAudio:					description = @"DV Audio";						break;
				case kAudioFormatVariableDurationDVAudio:	description = @"Variable Duration DV Audio";	break;
				case kAudioFormatTimeCode:					description = @"Audio Time Stamps";				break;
				case kAudioFormatMIDIStream:				description = @"MIDI";							break;
				case kAudioFormatParameterValueStream:		description = @"Parameter Value Stream";		break;
				case kAudioFormatAppleLossless:				description = @"Apple Lossless";				break;
					
				default:									description = (NSString *)UTCreateStringForOSType(desc->mFormatID);break;
			}
			
			[d setValue:description forKey:@"description"];
			
			[variantsA addObject:d];
		}			
		
		[result addObjectsFromArray:variantsA];
		free(variants);
	}
	
	free(formatIDs);
	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	return [[[result sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sd, nil]] retain] autorelease];
	//	return [[result retain] autorelease];
}

static NSMutableDictionary *
getCoreAudioFileTypeInfo(OSType filetype)
{
	OSStatus				err;
	UInt32					size;
	NSMutableDictionary		*result				= [NSMutableDictionary dictionaryWithCapacity:2];
	NSString				*fileTypeName		= nil;
	NSArray					*extensions			= nil;
	
	// file type name
	size = sizeof(NSString *);
	err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName, sizeof(UInt32), &filetype, &size, &fileTypeName);
	if(fileTypeName) {
		[result setValue:fileTypeName forKey:@"fileTypeName"];
	}
	
	// file extensions
	size = sizeof(NSArray *);
	err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ExtensionsForType, sizeof(OSType), &filetype, &size, &extensions);
	if(extensions) {
		[result setValue:extensions forKey:@"extensionsForType"];
	}
	
	[result setValue:getCoreAudioFileDataFormats(filetype) forKey:@"dataFormats"];
	
	return [[result retain] autorelease];
}

// Return an array of information on valid formats for output
NSMutableArray *
getCoreAudioWritableTypes()
{
	OSStatus			err;
	UInt32				size;
	UInt32				*fileFormats;
	unsigned			numFileFormats, i, j;
	NSMutableArray		*result;
	
	err					= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size);
	fileFormats			= malloc(size);
	if(NULL == fileFormats) {
		@throw [MallocException exceptionWithReason:[NSString stringWithFormat:@"Unable to allocate memory (%i:%s)", errno, strerror(errno)] userInfo:nil];
	}
	numFileFormats		= size / sizeof(UInt32);
	result				= [NSMutableArray arrayWithCapacity:numFileFormats];
	err					= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size, fileFormats);
	
	for(i = 0; i < numFileFormats; ++i) {
		NSMutableDictionary		*d				= [NSMutableDictionary dictionaryWithCapacity:3];
		NSArray					*dataFormats;
		
		[d setValue:[NSNumber numberWithUnsignedLong:fileFormats[i]] forKey:@"fileType"];
		[d addEntriesFromDictionary:getCoreAudioFileTypeInfo(fileFormats[i])];
		
		// Only add this file type if one of more of the dataFormats are writable
		dataFormats = [d valueForKey:@"dataFormats"];
		for(j = 0; j < [dataFormats count]; ++j) {
			if([[[dataFormats objectAtIndex:j] valueForKey:@"writable"] boolValue]) {
				[result addObject:d];		
				break;
			}
		}
	}
	
	free(fileFormats);
	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"fileTypeName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	return [[[result sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sd, nil]] retain] autorelease];
}
