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

#import <Cocoa/Cocoa.h>
#import "AudioMetadata.h"

@class CompactDiscDocument;

@interface Track : NSObject
{
	CompactDiscDocument		*_document;

	BOOL					_ripInProgress;
	unsigned				_activeEncoders;

	// View properties
	BOOL					_selected;
	
	// Metadata information
	NSString				*_title;
	NSString				*_artist;
	unsigned				_year;
	NSString				*_genre;
	NSString				*_composer;
	
	// Physical track properties
	unsigned 				_number;
	unsigned long			_firstSector;
	unsigned long			_lastSector;
	unsigned 				_channels;
	BOOL					_preEmphasis;
	BOOL					_copyPermitted;
	NSString				*_ISRC;
}

- (NSString *)				length;

- (CompactDiscDocument *)	document;

- (BOOL)			ripInProgress;
- (BOOL)			encodeInProgress;

- (BOOL)			selected;
- (NSColor *)		color;

- (NSString *)		title;
- (NSString *)		artist;
- (unsigned)		year;
- (NSString *)		genre;
- (NSString *)		composer;

- (unsigned long)	size;

- (unsigned)		minute;
- (unsigned)		second;
- (unsigned)		frame;

- (unsigned)		number;
- (unsigned long)	firstSector;
- (unsigned long)	lastSector;
- (unsigned)		channels;
- (BOOL)			preEmphasis;
- (BOOL)			copyPermitted;
- (NSString *)		ISRC;

// Mutators
- (void) setDocument:(CompactDiscDocument *)document;

- (void) setRipInProgress:(BOOL)ripInProgress;
- (void) encodeStarted;
- (void) encodeCompleted;

- (void) setSelected:(BOOL)selected;

- (void) setTitle:(NSString *)title;
- (void) setArtist:(NSString *)artist;
- (void) setYear:(unsigned)year;
- (void) setGenre:(NSString *)genre;
- (void) setComposer:(NSString *)composer;

- (void) setNumber:(unsigned)number;
- (void) setFirstSector:(unsigned long)firstSector;
- (void) setLastSector:(unsigned long)lastSector;
- (void) setChannels:(unsigned)channels;
- (void) setPreEmphasis:(BOOL)preEmphasis;
- (void) setCopyPermitted:(BOOL)copyPermitted;
- (void) setISRC:(NSString *)ISRC;

// Metadata access
- (AudioMetadata *)			metadata;

// Save/Restore
- (NSDictionary *)	getDictionary;
- (void)			setPropertiesFromDictionary:(NSDictionary *)properties;

- (void)			clearFreeDBData;

@end
