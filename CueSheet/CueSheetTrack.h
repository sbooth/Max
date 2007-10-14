/*
 *  $Id$
 *
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

#import <Cocoa/Cocoa.h>

#import "AudioMetadata.h"

@class CueSheetDocument;

@interface CueSheetTrack : NSObject <NSCopying>
{
	CueSheetDocument		*_document;
	NSString				*_filename;
	
	// View properties
	BOOL					_selected;
	
	// Metadata information
	NSString				*_title;
	NSString				*_artist;
	unsigned				_year;
	NSString				*_genre;
	NSString				*_composer;
	NSString				*_comment;
	
	// Physical track properties
	unsigned 				_number;
	unsigned				_firstSector;
	unsigned				_lastSector;
//	unsigned 				_channels;
	BOOL					_preEmphasis;
	BOOL					_copyPermitted;
	NSString				*_ISRC;
	BOOL					_dataTrack;
	unsigned				_preGap;
	unsigned				_postGap;
}

- (CueSheetDocument *)		document;
- (void)					setDocument:(CueSheetDocument *)document;

- (NSString *)		filename;
- (void)			setFilename:(NSString *)filename;

- (NSString *)		length;

- (BOOL)			selected;
- (void)			setSelected:(BOOL)selected;

- (NSString *)		title;
- (void)			setTitle:(NSString *)title;

- (NSString *)		artist;
- (void)			setArtist:(NSString *)artist;

- (unsigned)		year;
- (void)			setYear:(unsigned)year;

- (NSString *)		genre;
- (void)			setGenre:(NSString *)genre;

- (NSString *)		composer;
- (void)			setComposer:(NSString *)composer;

- (NSString *)		comment;
- (void)			setComment:(NSString *)comment;

- (unsigned)		minute;
- (unsigned)		second;
- (unsigned)		frame;

- (unsigned)		number;
- (void)			setNumber:(unsigned)number;

- (unsigned)		firstSector;
- (void)			setFirstSector:(unsigned)firstSector;

- (unsigned)		lastSector;
- (void)			setLastSector:(unsigned)lastSector;

//- (unsigned)		channels;
//- (void)			setChannels:(unsigned)channels;

- (BOOL)			preEmphasis;
- (void)			setPreEmphasis:(BOOL)preEmphasis;

- (BOOL)			copyPermitted;
- (void)			setCopyPermitted:(BOOL)copyPermitted;

- (NSString *)		ISRC;
- (void)			setISRC:(NSString *)ISRC;

- (BOOL)			dataTrack;
- (void)			setDataTrack:(BOOL)dataTrack;

- (unsigned)		preGap;
- (void)			setPreGap:(unsigned)preGap;

- (unsigned)		postGap;
- (void)			setPostGap:(unsigned)postGap;

	// Metadata access
- (AudioMetadata *)			metadata;

	// Save/Restore
- (NSDictionary *)	getDictionary;
- (void)			setPropertiesFromDictionary:(NSDictionary *)properties;

@end
