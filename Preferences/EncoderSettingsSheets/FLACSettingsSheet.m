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

#import "FLACSettingsSheet.h"

@implementation FLACSettingsSheet

+ (NSDictionary *) defaultSettings
{
	NSArray		*objects	= nil;
	NSArray		*keys		= nil;
	
	objects = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:6],
		[NSNumber numberWithInt:4096],
		[NSNumber numberWithBool:NO],
		[NSNumber numberWithBool:YES],
		[NSNumber numberWithBool:NO],
		[NSNumber numberWithInt:0],
		[NSNumber numberWithInt:0],
		[NSNumber numberWithInt:4],
		[NSNumber numberWithInt:8],
		nil];
	
	keys = [NSArray arrayWithObjects:
		@"compressionLevel", 
		@"padding", 
		@"exhaustiveModelSearch",
		@"enableMidSide", 
		@"enableLooseMidSide", 
		@"QLPCoeffPrecision", 
		@"minPartitionOrder", 
		@"maxPartitionOrder", 
		@"maxLPCOrder",
		nil];
	
	
	return [NSDictionary dictionaryWithObjects:objects forKeys:keys];
}

- (id) initWithSettings:(NSDictionary *)settings;
{
	if((self = [super initWithNibName:@"FLACSettingsSheet" settings:settings])) {
		return self;
	}
	return nil;
}

- (IBAction) userSelectedCompressionLevel:(id)sender
{
	// All compression ratio stuff "borrowed" from FLAC's main.c
	switch([sender selectedTag]) {
		case FLAC_COMPRESSION_LEVEL_0:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:2]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:2]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_1:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:2]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:2]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_2:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_3:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:6]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_4:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:8]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_5:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:3]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:8]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_6:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:4]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:8]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_7:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:6]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:8]		forKey:@"maxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_LEVEL_8:
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"exhaustiveModelSearch"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:YES]		forKey:@"enableMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithBool:NO]		forKey:@"enableLooseMidSide"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"QLPCoeffPrecision"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:0]		forKey:@"minPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:6]		forKey:@"maxPartitionOrder"];
			[[_settingsController selection] setValue:[NSNumber numberWithInt:12]		forKey:@"maxLPCOrder"];
			break;
	}
}

@end
