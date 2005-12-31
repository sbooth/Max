/*
 *  $Id: LAMEPreferencesController.m 283 2005-12-30 19:11:43Z sbooth $
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

#import "FLACPreferencesController.h"

enum {
	FLAC_COMPRESSION_RATIO_0			= 1,
	FLAC_COMPRESSION_RATIO_1			= 2,
	FLAC_COMPRESSION_RATIO_2			= 3,
	FLAC_COMPRESSION_RATIO_3			= 4,
	FLAC_COMPRESSION_RATIO_4			= 5,
	FLAC_COMPRESSION_RATIO_5			= 6,
	FLAC_COMPRESSION_RATIO_6			= 7,
	FLAC_COMPRESSION_RATIO_7			= 8,
	FLAC_COMPRESSION_RATIO_8			= 9,
	FLAC_COMPRESSION_RATIO_CUSTOM		= 0
};

@implementation FLACPreferencesController

- (id) init
{
	if((self = [super initWithWindowNibName:@"FLACPreferences"])) {
		return self;		
	}
	return nil;
}

- (IBAction) userSelectedCompressionRatio:(id)sender
{
	// All compression ratio stuff "borrowed" from FLAC's main.c
	switch([sender selectedTag]) {
		case FLAC_COMPRESSION_RATIO_0:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:2				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:2				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMaxLPCOrder"];
			break;
			
		case FLAC_COMPRESSION_RATIO_1:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:2				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:2				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_2:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_3:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:6				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_4:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:8				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_5:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:3				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:8				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_6:
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:4				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:8				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_7:
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:6				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:8				forKey:@"flacMaxLPCOrder"];
			break;

		case FLAC_COMPRESSION_RATIO_8:
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacExhaustiveModelSearch"];
			[[NSUserDefaults standardUserDefaults] setBool:YES				forKey:@"flacEnableMidSide"];
			[[NSUserDefaults standardUserDefaults] setBool:NO				forKey:@"flacEnableLooseMidSide"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacQLPCoeffPrecision"];
			[[NSUserDefaults standardUserDefaults] setInteger:0				forKey:@"flacMinPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:6				forKey:@"flacMaxPartitionOrder"];
			[[NSUserDefaults standardUserDefaults] setInteger:12			forKey:@"flacMaxLPCOrder"];
			break;
	}
}

@end
