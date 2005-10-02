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

#import "CompactDisc.h"
#import "CDDBMatch.h"

NSString *gDataDir;

@interface CompactDiscController : NSObject
{
	IBOutlet NSTableView			*_tracksTable;
	IBOutlet NSDrawer				*_trackDrawer;
	IBOutlet NSDrawer				*_statusDrawer;
	IBOutlet NSButton				*_trackInfoButton;
	IBOutlet NSButton				*_encodeButton;
	IBOutlet NSButton				*_stopButton;
	IBOutlet NSProgressIndicator	*_ripProgressIndicator;
	IBOutlet NSTextField			*_ripTrack;
	IBOutlet NSWindow				*_window;
		
	CompactDisc						*_disc;
	NSNumber						*_stop;
}

- (IBAction) selectAll:(id)sender;
- (IBAction) selectNone:(id)sender;

- (IBAction) showTrackInfo:(id)sender;
- (IBAction) encode:(id)sender;
- (IBAction) stop:(id)sender;
- (IBAction) getCDInformation:(id)sender;

- (CompactDiscController *) initWithDisc: (CompactDisc *) disc;

- (BOOL) emptySelection;

- (void) displayExceptionSheet:(NSException *)exception;

- (void) discUnmounted;

- (void) encodeDidStart:(id) object;
- (void) encodeDidStop:(id) object;
- (void) encodeDidComplete:(id) object;
- (void) updateEncodeProgress:(id) object;

- (void) updateDiscFromCDDB:(CDDBMatch *)info;

@end
