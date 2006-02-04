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

#import "FormatsPreferencesController.h"
#import "CoreAudioUtilities.h"

#include "sndfile/sndfile.h"


@implementation FormatsPreferencesController

- (id) init
{
	SF_FORMAT_INFO			formatInfo;
	SF_INFO					info;
	int						i, j;
	int						format, majorCount, subtypeCount;

	if((self = [super initWithWindowNibName:@"FormatsPreferences"])) {
		
		_coreAudioFormats			= [getCoreAudioWritableTypes() retain];
		_libsndfileFormats			= [[NSMutableArray arrayWithCapacity:20] retain];
		
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

- (void) dealloc
{
	[_coreAudioFormats release];
	[_libsndfileFormats release];
	[super dealloc];
}

- (IBAction) addLibsndfileFormat:(id)sender
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:4];
	
	NSArray *types = [_libsndfileTypesController selectedObjects];
	if(0 < [types count]) {
		NSDictionary *type = [types objectAtIndex:0];
		[result setValue:[type valueForKey:@"sndfileFormat"] forKey:@"sndfileFormat"];
		[result setValue:[type valueForKey:@"type"] forKey:@"type"];
		[result setValue:[type valueForKey:@"extension"] forKey:@"extension"];

		NSArray *subtypes = [_libsndfileSubtypesController selectedObjects];
		if(0 < [subtypes count]) {
			NSDictionary *subtype = [subtypes objectAtIndex:0];
			[result addEntriesFromDictionary:subtype];
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
		[result setValue:[type valueForKey:@"fileType"] forKey:@"fileType"];
		[result setValue:[type valueForKey:@"fileTypeName"] forKey:@"fileTypeName"];
		[result setValue:[type valueForKey:@"extensionsForType"] forKey:@"extensionsForType"];
		
		NSArray *subtypes = [_coreAudioSubtypesController selectedObjects];
		if(0 < [subtypes count]) {
			NSDictionary *subtype = [subtypes objectAtIndex:0];
			[result addEntriesFromDictionary:subtype];
		}
	}

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
