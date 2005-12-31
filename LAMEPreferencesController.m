/*
 *  $Id$
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

#import "LAMEPreferencesController.h"
#import "MPEGEncoder.h"

@implementation LAMEPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"LAMEPreferences"])) {
		return self;		
	}
	return nil;
}

- (IBAction) userSelectedPreset:(id)sender
{
	switch([sender selectedTag]) {

		// 320 kbps CBR (-b 320)
		case LAME_USER_PRESET_BEST:
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_TARGET_BITRATE					forKey:@"lameTarget"];
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_ENCODING_ENGINE_QUALITY_HIGH		forKey:@"lameEncodingEngineQuality"];
			[[NSUserDefaults standardUserDefaults] setInteger:13									forKey:@"lameBitrate"];
			[[NSUserDefaults standardUserDefaults] setBool:YES										forKey:@"lameUseConstantBitrate"];
			[[NSUserDefaults standardUserDefaults] setBool:NO										forKey:@"lameMonoEncoding"];
			break;

		/*
		 Quality 70, Fast mode (-V 3 --vbr-new) (~175 kbps)
		 Quality 80, Fast mode (-V 2 --vbr-new) (~190 kbps)
		 Quality 90, Fast mode (-V 1 --vbr-new) (~210 kbps)
		 Quality 100, Fast mode (-V 0 --vbr-new) (~230 kbps)
		*/
		case LAME_USER_PRESET_TRANSPARENT:
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_TARGET_QUALITY					forKey:@"lameTarget"];
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_ENCODING_ENGINE_QUALITY_HIGH		forKey:@"lameEncodingEngineQuality"];
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_VARIABLE_BITRATE_MODE_FAST		forKey:@"lameVariableBitrateMode"];
			[[NSUserDefaults standardUserDefaults] setFloat:80.0									forKey:@"lameVBRQuality"];
			[[NSUserDefaults standardUserDefaults] setBool:NO										forKey:@"lameMonoEncoding"];
			break;

		/*
		 Quality 40, Fast mode (-V6 --vbr-new) (~115 kbps)
		 Quality 50, Fast mode (-V5 --vbr-new) (~130 kbps)
		 Quality 60, Fast mode (-V4 --vbr-new) (~160 kbps)
		 */
		case LAME_USER_PRESET_PORTABLE:
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_TARGET_QUALITY					forKey:@"lameTarget"];
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_ENCODING_ENGINE_QUALITY_HIGH		forKey:@"lameEncodingEngineQuality"];
			[[NSUserDefaults standardUserDefaults] setInteger:LAME_VARIABLE_BITRATE_MODE_FAST		forKey:@"lameVariableBitrateMode"];
			[[NSUserDefaults standardUserDefaults] setFloat:50.0									forKey:@"lameVBRQuality"];
			[[NSUserDefaults standardUserDefaults] setBool:NO										forKey:@"lameMonoEncoding"];
			break;
			
	}
}

@end
