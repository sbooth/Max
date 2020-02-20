/*
 *  Copyright (C) 2005 - 2020 Stephen F. Booth <me@sbooth.org>
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
	NSString				*_date;
	NSString				*_genre;
	NSString				*_composer;
	NSString				*_comment;

	// Region information
	Float32					_sampleRate;
	SInt64					_startingFrame;
	UInt32					_frameCount;

	// Track properties
	NSUInteger 				_number;
	NSString				*_ISRC;
	NSUInteger				_preGap;
	NSUInteger				_postGap;
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

- (NSString *)		date;
- (void)			setDate:(NSString *)date;

- (NSString *)		genre;
- (void)			setGenre:(NSString *)genre;

- (NSString *)		composer;
- (void)			setComposer:(NSString *)composer;

- (NSString *)		comment;
- (void)			setComment:(NSString *)comment;

- (NSUInteger)		number;
- (void)			setNumber:(NSUInteger)number;

- (Float32)			sampleRate;
- (void)			setSampleRate:(Float32)sampleRate;

- (SInt64)			startingFrame;
- (void)			setStartingFrame:(SInt64)startingFrame;

- (UInt32)			frameCount;
- (void)			setFrameCount:(UInt32)frameCount;

- (NSString *)		ISRC;
- (void)			setISRC:(NSString *)ISRC;

- (NSUInteger)		preGap;
- (void)			setPreGap:(NSUInteger)preGap;

- (NSUInteger)		postGap;
- (void)			setPostGap:(NSUInteger)postGap;

	// Metadata access
- (AudioMetadata *)			metadata;

	// Save/Restore
- (NSDictionary *)	getDictionary;
- (void)			setPropertiesFromDictionary:(NSDictionary *)properties;

@end
