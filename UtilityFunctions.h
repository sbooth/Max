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

#include <FLAC/metadata.h>

#import "AudioMetadata.h"

#ifdef __cplusplus
extern "C" {
#endif

// Get data directory (~/Application Support/Max/)
NSString * getApplicationDataDirectory();

// Create directory structure for path
void createDirectoryStructure(NSString *path);
	
// Remove /: characters and replace with _
NSString * makeStringSafeForFilename(NSString *string);

// Return a unique filename based on basename and extension
NSString * generateUniqueFilename(NSString *basename, 
								  NSString *extension);

// Create path if it does not exist; throw an exception if it exists and is a file
void validateAndCreateDirectory(NSString *path);

// Get an array of file types with built-in support
NSArray * getBuiltinExtensions();

// Get an array of file types supported by libsndfile
NSArray * getLibsndfileExtensions();

// Get a timestamp in the ID3v2 format
NSString * getID3v2Timestamp();

// Add a Vorbis comment to a FLAC file
void addVorbisComment(FLAC__StreamMetadata		*block,
					  NSString					*key,
					  NSString					*value);

// Convert an NSImage to PNG data
NSData * getPNGDataForImage(NSImage *image);

// Return YES if at least one output format is selected
BOOL outputFormatsSelected();

#ifdef __cplusplus
}
#endif
