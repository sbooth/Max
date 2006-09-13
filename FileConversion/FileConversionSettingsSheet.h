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

enum {
	kDontOverwriteExistingFiles			= 0,
	kOverwriteExistingFiles				= 1,
	kPromptForExistingFiles				= 2
};

@interface FileConversionSettingsSheet : NSObject
{
	IBOutlet NSWindow				*_sheet;
	
	IBOutlet NSPopUpButton			*_outputDirectoryPopUpButton;
	IBOutlet NSPopUpButton			*_temporaryDirectoryPopUpButton;
	IBOutlet NSComboBox				*_fileNamingComboBox;
	IBOutlet NSPopUpButton			*_formatSpecifierPopUpButton;
	
	IBOutlet NSObjectController 	*_settingsController;
	IBOutlet NSArrayController 		*_postProcessingActionsController;
	
	NSMutableDictionary				*_settings;
}

- (id)					initWithSettings:(NSMutableDictionary *)settings;

- (NSWindow *)			sheet;

- (IBAction)			ok:(id)sender;

- (IBAction)			selectOutputDirectory:(id)sender;
- (IBAction)			selectTemporaryDirectory:(id)sender;

- (IBAction)			insertFileNamingFormatSpecifier:(id)sender;
- (IBAction)			saveFileNamingFormat:(id)sender;

- (IBAction)			addPostProcessingApplication:(id)sender;

@end
