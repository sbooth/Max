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

#import <Cocoa/Cocoa.h>

@class CompactDisc;

@interface Track : NSObject 
{
	// View properties
	NSNumber			*_selected;
	NSColor				*_color;
	
	// ID3 tags
	NSString			*_title;			// TALB
	NSString			*_artist;			// TPE1
	NSNumber			*_year;				// TYER
	NSNumber			*_genre;			// TCON
	
	// Physical track properties
	NSNumber			*_number;
	NSNumber			*_minute;
	NSNumber			*_second;
	NSNumber			*_frame;
	NSNumber			*_type;
	
	NSNumber			*_lastSector;
	
	CompactDisc			*_disc;
}

- (NSString *) getType;
- (NSString *) getChannels;
- (NSString *) getPreEmphasis;
- (NSString *) getCopyPermitted;
- (NSNumber *) getFirstSector;
- (NSNumber *) getSize;
- (NSColor *) getColor;

- (NSString *) getLength;

- (NSNumber *) getDuration;

- (NSDictionary *) getDictionary;
- (void) setPropertiesFromDictionary:(NSDictionary *)properties;
@end
