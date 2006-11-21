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

#import "GaplessUtilities.h"

#include <mp4v2/mp4.h>
#include <mp4v2/mp4util.h>
#include <mp4v2/mp4array.h>
#include <mp4v2/mp4track.h>
#include <mp4v2/mp4file.h>

#undef ASSERT
#define ASSERT(x)

#include <mp4v2/mp4property.h>
#include <mp4v2/mp4atom.h>
#include <mp4v2/atoms.h>

#include <cstdio>

void 
addMPEG4AACGaplessInformationAtom(NSString *filename, SInt64 totalFrames)
{
	MP4File				*file;
	NSString			*bundleVersion, *versionString;
	MP4Atom				*dashAtom, *meanAtom, *nameAtom, *dataAtom;
	MP4Property			*prop;
	MP4BytesProperty	*bytesProp;
	const char			*value;
	
	file		= new MP4File();
	
	file->Modify([filename fileSystemRepresentation]);

	// Set this atom so mp4v2 will flesh out the "ilst" atom (otherwise tagging will fail)
	bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	versionString = [NSString stringWithFormat:@"Max %@", bundleVersion];
	file->SetMetadataTool([versionString UTF8String]);
	
	// Add the incredibly annoying "----" atom, with the appropriate gapless info
	dashAtom	= file->AddDescendantAtoms("", "moov.udta.meta.ilst.----");

	meanAtom	= dashAtom->FindChildAtom("mean");
	prop		= meanAtom->GetProperty(2);

	if(BytesProperty == prop->GetType()) {
		value		= "com.apple.iTunes";
		bytesProp	= dynamic_cast<MP4BytesProperty *>(prop);		
		bytesProp->SetValue((const uint8_t *)value, strlen(value));
	}

	nameAtom	= dashAtom->FindChildAtom("name");
	prop		= nameAtom->GetProperty(2);
	
	if(BytesProperty == prop->GetType()) {
		value		= "iTunSMPB";
		bytesProp	= dynamic_cast<MP4BytesProperty *>(prop);
		bytesProp->SetValue((const uint8_t *)value, strlen(value));
	}

	dataAtom	= dashAtom->FindChildAtom("data");
	prop		= dataAtom->GetProperty(3);
	
	if(BytesProperty == prop->GetType()) {
		NSString	*newValue;
		unsigned	delay;
		unsigned	padding;
		
		delay		= 0x840;
		padding		= (unsigned)ceil((totalFrames + 2112) / 1024.0) * 1024 - (totalFrames + 2112);

		newValue	= [NSString stringWithFormat:@"00000000 %.8x %.8x %.16qx 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000", 
			delay, padding, totalFrames];
		value		= [newValue cStringUsingEncoding:NSASCIIStringEncoding];

		bytesProp	= dynamic_cast<MP4BytesProperty *>(prop);
		bytesProp->SetValue((const uint8_t *)value, strlen(value));
	}
	
	file->Close();
	
	delete file;
}
