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

#import "GaplessUtilities.h"

#include <mp4v2/mp4v2.h>

void 
addMPEG4AACGaplessInformationAtom(NSString *filename, SInt64 totalFrames)
{
	NSCParameterAssert(nil != filename);
	
	MP4FileHandle file = MP4Modify([filename fileSystemRepresentation], 0);
	if(file == MP4_INVALID_FILE_HANDLE)
		return;

	MP4ItmfItem *smpb = MP4ItmfItemAlloc("----", 1);
	smpb->mean = strdup("com.apple.iTunes");
	smpb->name = strdup("iTunSMPB");

	// Construct the encoder delay and padding
	unsigned delay		= 0x840;
	unsigned padding	= ceil((totalFrames + 2112) / 1024.0) * 1024 - (totalFrames + 2112);
	
	NSString *value	= [NSString stringWithFormat:@"00000000 %.8x %.8x %.16qx 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000", delay, padding, totalFrames];
	
	const char *const utf8 = [value UTF8String];
	
	MP4ItmfData *data = &smpb->dataList.elements[0];
	data->typeCode = MP4_ITMF_BT_UTF8;
	data->valueSize = (uint32_t)strlen(utf8);
	data->value = (uint8_t *)malloc( data->valueSize );

	memcpy(data->value, utf8, data->valueSize);
	
	// Add to mp4 file
	MP4ItmfAddItem(file, smpb);	
	MP4ItmfItemFree(smpb);
	
	MP4Close(file, 0);
}

void 
addMPEG4AACBitrateInformationAtom(NSString *filename, UInt32 bitrate, int bitrateMode)
{
	NSCParameterAssert(nil != filename);
	
	MP4FileHandle file = MP4Modify([filename fileSystemRepresentation], 0);
	if(file == MP4_INVALID_FILE_HANDLE)
		return;
	
	MP4ItmfItem *smpb = MP4ItmfItemAlloc("----", 1);
	smpb->mean = strdup("com.apple.iTunes");
	smpb->name = strdup("Encoding Params");

	// Consruct the block
	NSMutableData *blockData = [NSMutableData data];

	NSString *atomName = @"vers";
	const char *utf8 = [atomName UTF8String];
	[blockData appendBytes:utf8 length:strlen(utf8)];
	UInt32 num = OSSwapHostToBigInt32(1);
	[blockData appendBytes:&num length:4];

	// CBR, ABR, VBR, VBR (true)
	atomName = @"acbf";
	utf8 = [atomName UTF8String];
	[blockData appendBytes:utf8 length:strlen(utf8)];
	num = OSSwapHostToBigInt32(bitrateMode);
	[blockData appendBytes:&num length:4];

	atomName = @"brat";
	utf8 = [atomName UTF8String];
	[blockData appendBytes:utf8 length:strlen(utf8)];
	num = OSSwapHostToBigInt32(bitrate);
	[blockData appendBytes:&num length:4];

	atomName = @"cdcv";
	utf8 = [atomName UTF8String];
	[blockData appendBytes:utf8 length:strlen(utf8)];
	num = OSSwapHostToBigInt32(0x10504);
	[blockData appendBytes:&num length:4];

	MP4ItmfData *data = &smpb->dataList.elements[0];
	data->typeCode = MP4_ITMF_BT_IMPLICIT;
	data->valueSize = (uint32_t)[blockData length];
	data->value = (uint8_t *)malloc( data->valueSize );
	
	memcpy(data->value, [blockData bytes], data->valueSize);
	
	// Add to mp4 file
	MP4ItmfAddItem(file, smpb);	
	MP4ItmfItemFree(smpb);
	
	MP4Close(file, 0);
}
