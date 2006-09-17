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

enum ReaderSeekType {
	kReaderSeekTypeAbsolute,
	kReaderSeekTypeCurrent,
	kReaderSeekTypeEnd
};
typedef enum ReaderSeekType ReaderSeekType;

// An abstraction of a data source- likely represents an URL or file
@protocol ReaderMethods

- (off_t)			totalBytes;
- (off_t)			currentOffset;

- (BOOL)			isSeekable;
- (off_t)			seekToOffset:(off_t)offset seekType:(ReaderSeekType)seekType;

- (ssize_t)			readData:(void *)buffer byteCount:(size_t)byteCount;

@end
