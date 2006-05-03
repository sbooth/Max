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

@interface CueSheetDocument : NSDocument
{
	// Disc properties
	int					_mode;
	NSString			*_MCN;

	// CD-TEXT
	NSString			*_title;
	NSString			*_performer;
	NSString			*_songwriter;
	NSString			*_composer;
	NSString			*_arranger;
	NSString			*_UPC;
	
	NSMutableArray		*_tracks;
}

- (int)				mode;
- (void)			setMode:(int)mode;

- (NSString *)		MCN;
- (void)			setMCN:(NSString *)MCN;

- (NSString *)		title;
- (void)			setTitle:(NSString *)title;

- (NSString *)		performer;
- (void)			setPerformer:(NSString *)performer;

- (NSString *)		songwriter;
- (void)			setSongwriter:(NSString *)songwriter;

- (NSString *)		composer;
- (void)			setComposer:(NSString *)composer;

- (NSString *)		arranger;
- (void)			setArranger:(NSString *)arranger;

- (NSString *)		UPC;
- (void)			setUPC:(NSString *)UPC;

- (unsigned)		countOfTracks;
- (id)				objectInTracksAtIndex:(unsigned)index;

- (void)			insertObject:(id)track inTracksAtIndex:(unsigned)index;
- (void)			removeObjectFromTracksAtIndex:(unsigned)index;

@end
