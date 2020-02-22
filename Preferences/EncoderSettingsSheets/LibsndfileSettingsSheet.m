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

#import "LibsndfileSettingsSheet.h"

#include <sndfile/sndfile.h>

@implementation LibsndfileSettingsSheet

+ (NSDictionary *) defaultSettings
{
	return [NSDictionary dictionary];
}

- (id) initWithSettings:(NSDictionary *)settings
{
	SF_FORMAT_INFO			formatInfo;
	SF_FORMAT_INFO			subtypeInfo;
	SF_INFO					info;
	int						i, majorFormat, currentSubtypeFormat;
	int						subtypeCount;
	NSDictionary			*objectToSelect			= nil;
	NSDictionary			*subtype;
	NSArray					*objects;
	NSArray					*keys;
	
	if((self = [super initWithNibName:@"LibsndfileSettingsSheet" settings:settings])) {
		
		currentSubtypeFormat = [[settings objectForKey:@"subtypeFormat"] intValue];

		[self willChangeValueForKey:@"availableSubtypes"];
		_availableSubtypes		= [[NSMutableArray alloc] init];
		
		// Get the count of all available subtypes (even invalid ones for this format)
		sf_command(NULL, SFC_GET_FORMAT_SUBTYPE_COUNT, &subtypeCount, sizeof(int)) ;
		
		// The sndile major format we are dealing with
		majorFormat			= [[[self settings] objectForKey:@"majorFormat"] intValue];
				
		// Set up generic defaults for format verification
		memset(&info, 0, sizeof(SF_INFO));
		info.channels		= 1;
				
		// Query each available subtype to see if it is valid for this major format
		for(i = 0; i < subtypeCount; ++i) {

			// Request the subtype information
			subtypeInfo.format = i;
			
			sf_command (NULL, SFC_GET_FORMAT_SUBTYPE, &subtypeInfo, sizeof(subtypeInfo));
			
			// Flesh out the format description and determine if it is valud
			info.format		= (majorFormat & SF_FORMAT_TYPEMASK) | subtypeInfo.format;
			
			if(sf_format_check(&info)) {

				objects = [NSArray arrayWithObjects:
					[NSNumber numberWithInt:subtypeInfo.format],
					[NSString stringWithCString:subtypeInfo.name encoding:NSASCIIStringEncoding],
					nil];
				
				keys = [NSArray arrayWithObjects:
					@"subtypeFormat",
					@"subtypeName",
					nil];
				
				subtype = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
				
				// This subtype is valid, add it to the list
				[_availableSubtypes addObject:subtype];
				
				// If the subtype matches the one passed in settings, select it
				if(subtypeInfo.format == currentSubtypeFormat) {
					objectToSelect = subtype;
				}
			}
		}
		
		[self didChangeValueForKey:@"availableSubtypes"];

		// Get the name of the format
		formatInfo.format	= majorFormat | currentSubtypeFormat;
		
		sf_command(NULL, SFC_GET_FORMAT_INFO, &formatInfo, sizeof(formatInfo));
		
		[self setFormatName:[NSString stringWithCString:formatInfo.name encoding:NSASCIIStringEncoding]];
		
		if(nil != objectToSelect) {
			[_subtypesController setSelectedObjects:[NSArray arrayWithObject:objectToSelect]];
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_availableSubtypes release];	_availableSubtypes = nil;
	[_formatName release];			_formatName = nil;

	[super dealloc];
}

- (NSString *)		formatName									{ return [[_formatName retain] autorelease]; }
- (void)			setFormatName:(NSString *)formatName		{ [_formatName release]; _formatName = [formatName retain]; }

#pragma mark Delegate methods

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSArray				*selectedObjects	= [_subtypesController selectedObjects];
	NSDictionary		*subtypeInfo		= nil;
	SF_FORMAT_INFO		formatInfo;
	int					majorFormat;
	int					subtypeFormat;
	
	if(nil == selectedObjects) {
		return;
	}
	
	subtypeInfo = [selectedObjects objectAtIndex:0];

	// Get the name of the format
	majorFormat			= [[[self settings] objectForKey:@"majorFormat"] intValue];
	subtypeFormat		= [[subtypeInfo objectForKey:@"subtypeFormat"] intValue];
	formatInfo.format	= majorFormat | subtypeFormat;
	
	sf_command(NULL, SFC_GET_FORMAT_INFO, &formatInfo, sizeof(formatInfo));
	
	[self setFormatName:[NSString stringWithCString:formatInfo.name encoding:NSASCIIStringEncoding]];
	
	// Add the subtype information to our settings
	[_settings setObject:[subtypeInfo objectForKey:@"subtypeFormat"] forKey:@"subtypeFormat"];
}

@end
