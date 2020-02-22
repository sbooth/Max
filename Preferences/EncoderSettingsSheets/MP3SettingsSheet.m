/*
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import "MP3SettingsSheet.h"
#import "MP3Encoder.h"

@interface MP3SettingsSheet (Private)
- (void)	setPresetDescription;
@end

@implementation MP3SettingsSheet

+ (NSDictionary *) defaultSettings
{
	NSArray		*objects	= nil;
	NSArray		*keys		= nil;
	
	objects = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:8],
		[NSNumber numberWithInt:LAME_ENCODING_ENGINE_QUALITY_HIGH],
		[NSNumber numberWithInt:LAME_STEREO_MODE_DEFAULT],
		[NSNumber numberWithInt:4],
		[NSNumber numberWithInt:LAME_TARGET_QUALITY],
		[NSNumber numberWithBool:NO],
		[NSNumber numberWithInt:80],
		[NSNumber numberWithInt:LAME_VARIABLE_BITRATE_MODE_FAST],
		[NSNumber numberWithInt:LAME_USER_PRESET_TRANSPARENT],
		nil];
	
	keys = [NSArray arrayWithObjects:
		@"bitrate", 
		@"encodingEngineQuality", 
		@"stereoMode",
		@"quality",
		@"target",
		@"useConstantBitrate",
		@"VBRQuality", 
		@"variableBitrateMode", 
		@"userPreset", 
		nil];
	
	
	return [NSDictionary dictionaryWithObjects:objects forKeys:keys];
}

- (id) initWithSettings:(NSDictionary *)settings;
{
	if((self = [super initWithNibName:@"MP3SettingsSheet" settings:settings])) {
		return self;
	}
	return nil;
}

- (void) awakeFromNib
{
	[self setPresetDescription];
}

- (void) setPresetDescription
{
	switch([[_settings objectForKey:@"userPreset"] intValue]) {
		case LAME_USER_PRESET_BEST:
			[_presetDescription setStringValue:NSLocalizedStringFromTable(@"320 kbps constant bitrate (CBR)", @"Preferences", @"")];
			break;
		case LAME_USER_PRESET_TRANSPARENT:
			[_presetDescription setStringValue:NSLocalizedStringFromTable(@"~190 kbps variable bitrate (VBR)", @"Preferences", @"")];
			break;
		case LAME_USER_PRESET_PORTABLE:
			[_presetDescription setStringValue:NSLocalizedStringFromTable(@"~130 kbps variable bitrate (VBR)", @"Preferences", @"")];
			break;
		case LAME_USER_PRESET_CUSTOM:
			[_presetDescription setStringValue:NSLocalizedStringFromTable(@"Custom encoder settings", @"Preferences", @"")];
			break;
	}	
}

- (IBAction) userSelectedPreset:(id)sender
{
	switch([sender selectedTag]) {
		
		// 320 kbps CBR (-b 320)
		case LAME_USER_PRESET_BEST:
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_TARGET_BITRATE]					forKey:@"target"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_ENCODING_ENGINE_QUALITY_HIGH]	forKey:@"encodingEngineQuality"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:13]									forKey:@"bitrate"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]									forKey:@"useConstantBitrate"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_STEREO_MODE_DEFAULT]				forKey:@"stereoMode"];
			break;
			
			/*
			 Quality 70, Fast mode (-V 3 --vbr-new) (~175 kbps)
			 Quality 80, Fast mode (-V 2 --vbr-new) (~190 kbps)
			 Quality 90, Fast mode (-V 1 --vbr-new) (~210 kbps)
			 Quality 100, Fast mode (-V 0 --vbr-new) (~230 kbps)
			 */
		case LAME_USER_PRESET_TRANSPARENT:
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_TARGET_QUALITY]					forKey:@"target"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_ENCODING_ENGINE_QUALITY_HIGH]	forKey:@"encodingEngineQuality"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_VARIABLE_BITRATE_MODE_FAST]		forKey:@"variableBitrateMode"];
			[[_settingsController selection] setValue:[NSNumber numberWithDouble:80.0]								forKey:@"VBRQuality"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_STEREO_MODE_DEFAULT]				forKey:@"stereoMode"];
			break;
			
			/*
			 Quality 40, Fast mode (-V6 --vbr-new) (~115 kbps)
			 Quality 50, Fast mode (-V5 --vbr-new) (~130 kbps)
			 Quality 60, Fast mode (-V4 --vbr-new) (~160 kbps)
			 */
		case LAME_USER_PRESET_PORTABLE:
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_TARGET_QUALITY]					forKey:@"target"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_ENCODING_ENGINE_QUALITY_HIGH]	forKey:@"encodingEngineQuality"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_VARIABLE_BITRATE_MODE_FAST]		forKey:@"variableBitrateMode"];
			[[_settingsController selection] setValue:[NSNumber numberWithDouble:50.0]								forKey:@"VBRQuality"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:LAME_STEREO_MODE_DEFAULT]				forKey:@"stereoMode"];
			break;
	}
	
	[self setPresetDescription];
}

@end
