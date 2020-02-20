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

#import "CoreAudioSettingsSheet.h"
#import "CoreAudioUtilities.h"

@implementation CoreAudioSettingsSheet

+ (NSDictionary *)	defaultSettings		{ return [NSDictionary dictionary]; }

- (id) initWithSettings:(NSDictionary *)settings;
{
	NSArray					*coreAudioFormats;
	unsigned				i;
	AudioFileTypeID			fileType				= 0;
	UInt32					formatID				= 0;
	UInt32					formatFlags				= 0;
	UInt32					bitsPerChannel			= 0;
	UInt32					subtypeFormatID			= 0;
	UInt32					subtypeFormatFlags		= 0;
	UInt32					subtypeBitsPerChannel	= 0;
	NSDictionary			*format					= nil;
	NSDictionary			*subtype				= nil;
	NSDictionary			*objectToSelect			= nil;

	
	if((self = [super initWithNibName:@"CoreAudioSettingsSheet" settings:settings])) {
		coreAudioFormats	= GetCoreAudioWritableTypes();

		fileType			= (AudioFileTypeID)[[settings objectForKey:@"fileType"] unsignedLongValue];
		formatID			= (UInt32)[[settings objectForKey:@"formatID"] unsignedLongValue];
		formatFlags			= (UInt32)[[settings objectForKey:@"formatFlags"] unsignedLongValue];
		bitsPerChannel		= (UInt32)[[settings objectForKey:@"bitsPerChannel"] unsignedLongValue];

		[self setFormatName:GetCoreAudioOutputFormatName(fileType, formatID, 0)];

		// Iterate through each CoreAudio file type and find the one matching ours
		for(i = 0; i < [coreAudioFormats count]; ++i) {

			format = [coreAudioFormats objectAtIndex:i];

			// Match, propagate the data format list
			if([[format objectForKey:@"fileType"] unsignedLongValue] == fileType) {
				[self willChangeValueForKey:@"availableSubtypes"];
				_availableSubtypes = [[format objectForKey:@"dataFormats"] retain];
				[self didChangeValueForKey:@"availableSubtypes"];
			}
		}

		// formatID will be zero if this is the first time this settings sheet has been displayed
		if(0 != formatID) {
			// Iterate through the data format list and select the one specified in the settings
			for(i = 0; i < [_availableSubtypes count]; ++i) {
				subtype					= [_availableSubtypes objectAtIndex:i];

				subtypeFormatID			= (UInt32)[[subtype objectForKey:@"formatID"] unsignedLongValue];
				subtypeFormatFlags		= (UInt32)[[subtype objectForKey:@"formatFlags"] unsignedLongValue];
				subtypeBitsPerChannel	= (UInt32)[[subtype objectForKey:@"bitsPerChannel"] unsignedLongValue];

				if(formatID == subtypeFormatID && formatFlags == subtypeFormatFlags && bitsPerChannel == subtypeBitsPerChannel) {
					objectToSelect = subtype;
				}
			}
			
			if(nil != objectToSelect) {
				[_subtypesController setSelectedObjects:[NSArray arrayWithObject:objectToSelect]];
			}
		}
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_availableSubtypes release];
	_availableSubtypes = nil;
	[_formatName release];
	_formatName = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	NSNumber		*useVBR;
	NSString		*keyPath;
	NSNumber		*selectedValue;
	
	useVBR			= [_settingsController valueForKeyPath:@"selection.useVBR"];
	keyPath			= ([useVBR boolValue] ? @"selection.bitratesVBR" : @"selection.bitrates");
	selectedValue	= [NSNumber numberWithInt:[[_bitratePopUpButton titleOfSelectedItem] intValue]];
	
	[_bitratePopUpButton unbind:@"content"];
	
	[_bitratePopUpButton bind:@"content"
					 toObject:_subtypesController
				  withKeyPath:keyPath
					  options:nil];
}

- (NSString *)		formatName									{ return [[_formatName retain] autorelease]; }
- (void)			setFormatName:(NSString *)formatName		{ [_formatName release]; _formatName = [formatName retain]; }

- (IBAction) vbrButtonClicked:(id)sender
{
	NSString		*keyPath;
	NSNumber		*selectedValue;
	NSArray			*newBitrates;
	
	selectedValue	= [NSNumber numberWithInt:[[_bitratePopUpButton titleOfSelectedItem] intValue]];
	keyPath			= (NSOnState == [sender state] ? @"selection.bitratesVBR" : @"selection.bitrates");

	[_bitratePopUpButton unbind:@"content"];
		
	[_bitratePopUpButton bind:@"content"
					 toObject:_subtypesController
				  withKeyPath:keyPath
					  options:nil];

	newBitrates		= [_subtypesController valueForKeyPath:keyPath];

	if(NO == [newBitrates containsObject:selectedValue]) {
		[_settingsController setValue:[_bitratePopUpButton itemTitleAtIndex:0] forKeyPath:@"selection.bitrate"];
	}
}

#pragma mark Delegate methods

- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSArray				*selectedObjects		= [_subtypesController selectedObjects];
	NSDictionary		*subtypeInfo			= nil;
	AudioFileTypeID		fileType				= 0;
	UInt32				formatID				= 0;
	UInt32				formatFlags				= 0;
	
	if(nil == selectedObjects) {
		return;
	}
	
	subtypeInfo = [selectedObjects objectAtIndex:0];
	
	// Update name
	fileType			= (AudioFileTypeID)[[[self settings] objectForKey:@"fileType"] unsignedLongValue];
	formatID			= (UInt32)[[subtypeInfo objectForKey:@"formatID"] unsignedLongValue];
	formatFlags			= (UInt32)[[subtypeInfo objectForKey:@"formatFlags"] unsignedLongValue];

	[self setFormatName:GetCoreAudioOutputFormatName(fileType, formatID, formatFlags)];

	// Add the subtype information to our settings	
	
	// The following keys will (should?!) be present in every CoreAudio dataFormat description
	[_settings setObject:[subtypeInfo objectForKey:@"formatID"] forKey:@"formatID"];
	[_settings setObject:[subtypeInfo objectForKey:@"formatFlags"] forKey:@"formatFlags"];
	
	// For later, make these customizable
	[_settings setObject:[subtypeInfo objectForKey:@"bitsPerChannel"] forKey:@"bitsPerChannel"];
	[_settings setObject:[subtypeInfo objectForKey:@"sampleRate"] forKey:@"sampleRate"];
	
	// This key may not be present for all formats
	if(nil != [subtypeInfo objectForKey:@"vbrAvailable"]) {
		[_settings setObject:[subtypeInfo objectForKey:@"vbrAvailable"] forKey:@"vbrAvailable"];
	}
	else {
		[_settings removeObjectForKey:@"vbrAvailable"];
	}
	
	// If the user didn't select a bitrate or quality, use the defaults
	if(nil == [_settings objectForKey:@"bitrate"] && nil != [subtypeInfo objectForKey:@"bitrate"]) {
		[_settings setObject:[subtypeInfo objectForKey:@"bitrate"] forKey:@"bitrate"];
	}
	
	if(nil == [_settings objectForKey:@"quality"] && nil != [subtypeInfo objectForKey:@"quality"]) {
		[_settings setObject:[subtypeInfo objectForKey:@"quality"] forKey:@"quality"];
	}
	
	// If they did and the format doesn't support it, unset it
	if(nil != [_settings objectForKey:@"bitrate"] && nil == [subtypeInfo objectForKey:@"bitrates"]) {
		[_settings removeObjectForKey:@"bitrate"];
	}
	
	if(nil != [_settings objectForKey:@"quality"] && (nil == [subtypeInfo objectForKey:@"quality"] || (nil != [subtypeInfo objectForKey:@"quality"] &&  0 == [[subtypeInfo objectForKey:@"quality"] intValue]))) {
		[_settings removeObjectForKey:@"quality"];
	}
}

@end
