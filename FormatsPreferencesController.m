/*
 *  $Id: PreferencesController.h 189 2005-12-01 01:55:55Z me $
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

#import "FormatsPreferencesController.h"

#include "sndfile.h"

#include <CoreAudio/CoreAudioTypes.h>
#include <CoreServices/CoreServices.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/AudioFormat.h>

static NSMutableArray *
getCAFileDataFormats(OSType filetype)
{
	OSStatus				err;
	UInt32					size;
	NSMutableArray			*result;
	int						numDataFormats, j, k;
	OSType					*formatIDs;
	
	err				= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size);
	numDataFormats	= size / sizeof(OSType);
	formatIDs		= malloc(size);
	err				= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableFormatIDs, sizeof(UInt32), &filetype, &size, formatIDs);
	result			= [NSMutableArray arrayWithCapacity:numDataFormats];
	
	for(j = 0; j < numDataFormats; ++j) {
		NSMutableDictionary *dfi = [NSMutableDictionary dictionaryWithCapacity:5];
		
		[dfi setValue:(NSString *)UTCreateStringForOSType(formatIDs[j]) forKey:@"formatID"];
		
		AudioFileTypeAndFormatID tf = { filetype, formatIDs[j] };
		err							= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size);
		int numVariants				= size / sizeof(AudioStreamBasicDescription);
		NSMutableArray *variantsA	= [NSMutableArray arrayWithCapacity:numVariants];
		AudioStreamBasicDescription *variants = malloc(size);
		err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(AudioFileTypeAndFormatID), &tf, &size, variants);
		
		for(k = 0; k < numVariants; ++k) {
			AudioStreamBasicDescription *desc = &variants[k];
			NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:8];
			[d setValue:[NSNumber numberWithDouble:desc->mSampleRate] forKey:@"sampleRate"];
			[d setValue:(NSString *)UTCreateStringForOSType(desc->mFormatID) forKey:@"formatID"];
			[d setValue:[NSNumber numberWithUnsignedLong:desc->mFormatFlags] forKey:@"formatFlags"];
			[d setValue:[NSNumber numberWithUnsignedLong:desc->mBitsPerChannel] forKey:@"bitsPerChannel"];

			NSString *description;

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
//	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
//	return [[[result sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sd, nil]] retain] autorelease];
	return [[result retain] autorelease];
}

static NSMutableDictionary *
getCAFileTypeInfo(OSType filetype)
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
	
	[result setValue:getCAFileDataFormats(filetype) forKey:@"dataFormats"];
	
	return [[result retain] autorelease];
}

static NSMutableArray *
getCAWritableTypes()
{
	OSStatus			err;
	UInt32				size;
	UInt32				*fileTypes;
	int					numFileFormats, i;
	NSMutableArray		*result;
	
	// get all file types
	err					= AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size);
	numFileFormats		= size / sizeof(UInt32);
	result				= [NSMutableArray arrayWithCapacity:numFileFormats];
	fileTypes			= malloc(size);
	err					= AudioFileGetGlobalInfo(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size, fileTypes);
	
	for(i = 0; i < numFileFormats; ++i) {
		NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:3];
		
		[d setValue:(NSString *)UTCreateStringForOSType(fileTypes[i]) forKey:@"fileType"];
		[d addEntriesFromDictionary:getCAFileTypeInfo(fileTypes[i])];
		
		[result addObject:d];		
	}
	
	free(fileTypes);
	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey:@"fileTypeName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	return [[[result sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sd, nil]] retain] autorelease];
}

/*static NSMutableArray *
getCAOutputFormats() 
{
	OSStatus			err;
	UInt32				size;
	UInt32				*writableFormats;
	int					numWritableFormats, i;
	NSMutableArray		*result;
	
	// get all writable formats
	err					= AudioFormatGetPropertyInfo(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size);
	numWritableFormats	= size / sizeof(UInt32);
	result				= [NSMutableArray arrayWithCapacity:numWritableFormats];
	writableFormats		= malloc(numWritableFormats * sizeof(UInt32));
	err					= AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size, writableFormats);
	
	for(i = 0; i < numWritableFormats; ++i) {
		[result addObject:(NSString *)UTCreateStringForOSType(writableFormats[i])];		
	}
	
	free(writableFormats);
	return [[result retain] autorelease];
}*/

@implementation FormatsPreferencesController

- (id) init
{
	SF_FORMAT_INFO			formatInfo;
	SF_INFO					info;
	int						i, j;
	int						format, majorCount, subtypeCount;

	if((self = [super initWithWindowNibName:@"FormatsPreferences"])) {
		
		_coreAudioFormats			= getCAWritableTypes();
		_libsndfileFormats	= [NSMutableArray arrayWithCapacity:20];
		
		sf_command(NULL, SFC_GET_FORMAT_MAJOR_COUNT, &majorCount, sizeof(int)) ;
		sf_command(NULL, SFC_GET_FORMAT_SUBTYPE_COUNT, &subtypeCount, sizeof(int)) ;
		
		// Generic defaults
		info.channels		= 1 ;
		info.samplerate		= 0;

		// Loop through each major mode
		for(i = 0; i < majorCount; ++i) {

			NSMutableDictionary		*type;
			NSMutableArray			*subtypes;
			NSMutableDictionary		*subtype;
						
			formatInfo.format = i;
			
			sf_command(NULL, SFC_GET_FORMAT_MAJOR, &formatInfo, sizeof(formatInfo));
			
			type		= [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:formatInfo.format], [NSString stringWithUTF8String:formatInfo.name], [NSString stringWithUTF8String:formatInfo.extension], nil] 
															 forKeys:[NSArray arrayWithObjects:@"sndfileFormat", @"type", @"extension", nil]];
			subtypes	= [NSMutableArray arrayWithCapacity:20];
			format		= formatInfo.format;
			
			// And query each subtype to see if it is valid
			for(j = 0; j < subtypeCount; ++j) {
				formatInfo.format = j;
				
				sf_command (NULL, SFC_GET_FORMAT_SUBTYPE, &formatInfo, sizeof(formatInfo));
				
				format			= (format & SF_FORMAT_TYPEMASK) | formatInfo.format;
				info.format		= format;
				
				if(sf_format_check(&info)) {
					subtype = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:info.format], [NSString stringWithUTF8String:formatInfo.name], nil]  
																 forKeys:[NSArray arrayWithObjects:@"sndfileFormat", @"kind", nil]];
					[subtypes addObject:subtype];
				}
			}
			
			[type setObject:subtypes forKey:@"subtypes"];
			[_libsndfileFormats addObject:type];
		}
		
		return self;		
	}
	return nil;
}

- (IBAction) addLibsndfileFormat:(id)sender
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:4];
	
	NSArray *types = [_libsndfileTypesController selectedObjects];
	if(0 < [types count]) {
		NSDictionary *type = [types objectAtIndex:0];
//		[result addEntriesFromDictionary:type];
		[result setValue:[type valueForKey:@"sndfileFormat"] forKey:@"sndfileFormat"];
		[result setValue:[type valueForKey:@"type"] forKey:@"type"];
		[result setValue:[type valueForKey:@"extension"] forKey:@"extension"];

		NSArray *subtypes = [_libsndfileSubtypesController selectedObjects];
		if(0 < [subtypes count]) {
			NSDictionary *subtype = [subtypes objectAtIndex:0];
			[result addEntriesFromDictionary:subtype];
//			[result setValue:[subtype valueForKey:@"sndfileFormat"] forKey:@"sndfileFormat"];
//			[result setValue:[subtype valueForKey:@"kind"] forKey:@"kind"];
		}
	}
	
	if(NO == [[_libsndfileSelectedFormatsController arrangedObjects] containsObject:result]) {
		[_libsndfileSelectedFormatsController addObject:result];
	}
}

- (IBAction) removeLibsndfileFormat:(id)sender
{
	if(NSNotFound != [_libsndfileSelectedFormatsController selectionIndex]) {
		[_libsndfileSelectedFormatsController removeObjectAtArrangedObjectIndex:[_libsndfileSelectedFormatsController selectionIndex]];
	}
}

- (IBAction) addCoreAudioFormat:(id)sender
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:4];
	
	NSArray *types = [_coreAudioTypesController selectedObjects];
	if(0 < [types count]) {
		NSDictionary *type = [types objectAtIndex:0];
//		[result addEntriesFromDictionary:type];
		[result setValue:[type valueForKey:@"fileType"] forKey:@"fileType"];
		[result setValue:[type valueForKey:@"fileTypeName"] forKey:@"fileTypeName"];
		[result setValue:[type valueForKey:@"extensionsForType"] forKey:@"extensionsForType"];
		
		NSArray *subtypes = [_coreAudioSubtypesController selectedObjects];
		if(0 < [subtypes count]) {
			NSDictionary *subtype = [subtypes objectAtIndex:0];
			[result addEntriesFromDictionary:subtype];
//			[result setValue:[subtype valueForKey:@"sndfileFormat"] forKey:@"sndfileFormat"];
//			[result setValue:[subtype valueForKey:@"kind"] forKey:@"kind"];
		}
	}
	NSLog(@"%@", result);
	if(NO == [[_coreAudioSelectedFormatsController arrangedObjects] containsObject:result]) {
		[_coreAudioSelectedFormatsController addObject:result];
	}
}

- (IBAction) removeCoreAudioFormat:(id)sender
{
	if(NSNotFound != [_coreAudioSelectedFormatsController selectionIndex]) {
		[_coreAudioSelectedFormatsController removeObjectAtArrangedObjectIndex:[_coreAudioSelectedFormatsController selectionIndex]];
	}
}

@end
