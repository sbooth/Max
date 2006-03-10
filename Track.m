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

#import "Track.h"
#import "MissingResourceException.h"
#import "UtilityFunctions.h"

#include <IOKit/storage/IOCDTypes.h>

@interface Track (Private)
- (NSUndoManager *) undoManager;
@end

@implementation Track

+ (void)initialize 
{
	NSString				*trackDefaultsValuesPath;
    NSDictionary			*trackDefaultsValuesDictionary;
    
	@try {
		trackDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"TrackDefaults" ofType:@"plist"];
		if(nil == trackDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"TrackDefaults.plist" forKey:@"filename"]];
		}
		trackDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:trackDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:trackDefaultsValuesDictionary];
		
		[self setKeys:[NSArray arrayWithObjects:@"artist", @"year", @"genre", nil] triggerChangeNotificationsForDependentKey:@"color"];
		
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"minute"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"second"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"frame"];
		
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"size"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"length"];
		[self setKeys:[NSArray arrayWithObjects:@"firstSector", @"lastSector", nil] triggerChangeNotificationsForDependentKey:@"duration"];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
}

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (id) init
{
	if((self = [super init])) {

		_document				= nil;
		
		_ripInProgress		= NO;
		_activeEncoders		= 0;
		
		_selected			= NO;
		
		_title				= nil;
		_artist				= nil;
		_year				= 0;
		_genre				= nil;
		_composer			= nil;
		
		_number				= 0;
		_firstSector		= 0;
		_lastSector			= 0;
		_channels			= 0;
		_preEmphasis		= NO;
		_copyPermitted		= NO;
		_ISRC				= nil;
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_document release];
	
	[_title release];
	[_artist release];
	[_genre release];
	[_composer release];

	[_ISRC release];

	[super dealloc];
}

- (NSString *) description
{
	NSString			*discArtist			= [_document artist];
	NSString			*trackArtist		= [self artist];
	NSString			*artist;
	NSString			*trackTitle			= [self title];
	
	artist = trackArtist;
	if(nil == artist) {
		artist = discArtist;
		if(nil == artist) {
			artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
		}
	}
	if(nil == trackTitle) {
		trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
	}
	
	
	if([[_document valueForKey:@"multiArtist"] boolValue]) {
		return [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
	}
	else {
		return [NSString stringWithFormat:@"%@", trackTitle];		
	}
}

#pragma mark Accessors

- (unsigned) minute
{
	unsigned long	sector		= _firstSector;
	unsigned long	offset		= _lastSector - sector + 1;
	
	return (unsigned) (offset / (60 * 75));
}

- (unsigned) second
{
	unsigned long	sector		= _firstSector;
	unsigned long	offset		= _lastSector - sector + 1;
	
	return (unsigned) ((offset / 75) % 60);
}

- (unsigned) frame
{
	unsigned long	sector		= _firstSector;
	unsigned long	offset		= _lastSector - sector + 1;
	
	return (unsigned) (offset % 75);
}


/*- (NSString *) getPreEmphasis
{
	return [_preEmphasis boolValue] ? NSLocalizedStringFromTable(@"Yes", @"General", @"") : NSLocalizedStringFromTable(@"No", @"General", @"");
}*/

- (CompactDiscDocument *)	document			{ return _document; }
- (NSUndoManager *)			undoManager			{ return [_document undoManager]; }

- (BOOL)					ripInProgress		{ return _ripInProgress; }
- (BOOL)					encodeInProgress	{ return (0 != _activeEncoders); }

- (BOOL)					selected			{ return _selected; }

- (unsigned)				number				{ return _number; }
- (unsigned long)			firstSector			{ return _firstSector; }
- (unsigned long)			lastSector			{ return _lastSector; }
- (unsigned)				channels			{ return _channels; }
- (BOOL)					preEmphasis			{ return _preEmphasis; }
- (BOOL)					copyPermitted		{ return _copyPermitted; }
// ? NSLocalizedStringFromTable(@"Yes", @"General", @"") : NSLocalizedStringFromTable(@"No", @"General", @"");
- (unsigned long)			size				{ return ((_lastSector - _firstSector) * kCDSectorSizeCDDA); }
- (NSString *)				length				{ return [NSString stringWithFormat:@"%i:%02i", [self minute], [self second]]; }

- (NSString *)				title				{ return _title; }
- (NSString *)				artist				{ return _artist; }
- (unsigned)				year				{ return _year; }
- (NSString *)				genre				{ return _genre; }
- (NSString *)				composer			{ return _composer; }
- (NSString *)				ISRC				{ return _ISRC; }


- (NSColor *) color
{
	NSColor		*result;
	NSData		*data;
	
	result = nil;
	
	if(nil != _artist || nil != _year || nil != _genre) {
		data = [[NSUserDefaults standardUserDefaults] dataForKey:@"customTrackColor"];
		if(nil != data) {
			result = (NSColor *)[NSUnarchiver unarchiveObjectWithData:data];
		}
	}
	
	return result;
}

#pragma mark Mutators

- (void) setDocument:(CompactDiscDocument *)document	{ [_document release]; _document = [document retain]; }

- (void) setRipInProgress:(BOOL)ripInProgress			{ _ripInProgress = ripInProgress; }

- (void) setSelected:(BOOL)selected						{ _selected = selected; }

- (void) setNumber:(unsigned)number						{ _number = number; }
- (void) setFirstSector:(unsigned long)firstSector		{ _firstSector = firstSector; }
- (void) setLastSector:(unsigned long)lastSector		{ _lastSector = lastSector; }
- (void) setChannels:(unsigned)channels					{ _channels = channels; }
- (void) setPreEmphasis:(BOOL)preEmphasis				{ _preEmphasis = preEmphasis; }
- (void) setCopyPermitted:(BOOL)copyPermitted			{ _copyPermitted = copyPermitted; }
- (void) setISRC:(NSString *)ISRC						{ [_ISRC release]; _ISRC = ISRC; }

- (void) encodeStarted
{
	[self willChangeValueForKey:@"encodeInProgress"];
	++_activeEncoders;
	[self didChangeValueForKey:@"encodeInProgress"];
}

- (void) encodeCompleted
{
	[self willChangeValueForKey:@"encodeInProgress"];
	--_activeEncoders;
	[self didChangeValueForKey:@"encodeInProgress"];
}

- (void) setTitle:(NSString *)title
{
	if(NO == [_title isEqualToString:title]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setTitle:) object:_title];
		[[self undoManager] setActionName:@"Track Title"];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [_artist isEqualToString:artist]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setArtist:) object:_artist];
		[[self undoManager] setActionName:@"Track Artist"];
		[_artist release];
		_artist = [artist retain];
	}
}

- (void) setYear:(unsigned)year
{
	if(_year != year) {
		[[[self undoManager] prepareWithInvocationTarget:self] setYear:_year];
		[[self undoManager] setActionName:@"Track Year"];
		_year = year;
	}
}

- (void) setGenre:(NSString *)genre
{
	if(NO == [_genre isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:@"Track Genre"];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [_composer isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:@"Track Composer"];
		[_composer release];
		_composer = [composer retain];
	}
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
	
	[result setValue:[NSNumber numberWithBool:_selected] forKey:@"selected"];
	//[result setValue:_color forKey:@"color"];

	[result setValue:[self title] forKey:@"title"];
	[result setValue:[self artist] forKey:@"artist"];
	[result setValue:[NSNumber numberWithUnsignedInt:[self year]] forKey:@"year"];
	[result setValue:[self genre] forKey:@"genre"];

	[result setValue:[NSNumber numberWithUnsignedInt:[self number]] forKey:@"number"];
	[result setValue:[NSNumber numberWithUnsignedLong:[self firstSector]] forKey:@"firstSector"];
	[result setValue:[NSNumber numberWithUnsignedLong:[self lastSector]] forKey:@"lastSector"];
	[result setValue:[NSNumber numberWithUnsignedInt:[self channels]] forKey:@"channels"];
	[result setValue:[NSNumber numberWithBool:[self preEmphasis]] forKey:@"preEmphasis"];
	[result setValue:[NSNumber numberWithBool:[self copyPermitted]] forKey:@"copyPermitted"];
	[result setValue:_ISRC forKey:@"ISRC"];
	
	return [[result retain] autorelease];
}

- (void) setPropertiesFromDictionary:(NSDictionary *)properties
{	
	[_title release];
	[_artist release];
	[_genre release];
	[_composer release];
	
	_title			= [[properties valueForKey:@"title"] retain];
	_artist			= [[properties valueForKey:@"artist"] retain];
	_year			= [[properties valueForKey:@"year"] intValue];
	_genre			= [[properties valueForKey:@"genre"] retain];
	_composer		= [[properties valueForKey:@"composer"] retain];	
	
	[self setValue:[properties valueForKey:@"selected"] forKey:@"selected"];
	[self setValue:[properties valueForKey:@"color"] forKey:@"color"];
	
	[self setValue:[properties valueForKey:@"title"] forKey:@"title"];
	[self setValue:[properties valueForKey:@"artist"] forKey:@"artist"];
	[self setValue:[properties valueForKey:@"year"] forKey:@"year"];
	[self setValue:[properties valueForKey:@"genre"] forKey:@"genre"];

	[self setValue:[properties valueForKey:@"number"] forKey:@"number"];
	[self setValue:[properties valueForKey:@"firstSector"] forKey:@"firstSector"];
	[self setValue:[properties valueForKey:@"lastSector"] forKey:@"lastSector"];
	[self setValue:[properties valueForKey:@"channels"] forKey:@"channels"];
	[self setValue:[properties valueForKey:@"preEmphasis"] forKey:@"preEmphasis"];
	[self setValue:[properties valueForKey:@"copyPermitted"] forKey:@"copyPermitted"];
	[self setValue:[properties valueForKey:@"ISRC"] forKey:@"ISRC"];
}

- (id) copyWithZone:(NSZone *)zone
{
	Track *copy = [[Track allocWithZone:zone] init];
	
	[copy setDocument:_document];
	
	[copy setSelected:[self selected]];
	//[copy setValue:_color forKey:@"color"];
	
	[copy setTitle:[self title]];
	[copy setArtist:[self artist]];
	[copy setYear:[self year]];
	[copy setGenre:[self genre]];
	[copy setComposer:[self composer]];
	
	[copy setNumber:_number];
	[copy setFirstSector:_firstSector];
	[copy setLastSector:_lastSector];
	[copy setChannels:_channels];
	[copy setPreEmphasis:_preEmphasis];
	[copy setCopyPermitted:_copyPermitted];
	[copy setISRC:_ISRC];

	return copy;
}

- (AudioMetadata *) metadata
{
	AudioMetadata *result = [[AudioMetadata alloc] init];

	[result setTrackNumber:_number];
	[result setTrackTitle:_title];
	[result setTrackArtist:_artist];
	[result setTrackYear:_year];
	[result setTrackGenre:_genre];
	[result setTrackComposer:_composer];
//	[result setTrackComment:_comment];
	[result setISRC:_ISRC];
	
	[result setAlbumTrackCount:[[_document valueForKey:@"tracks"] count]];
	[result setAlbumTitle:[_document title]];
	[result setAlbumArtist:[_document artist]];
	[result setAlbumYear:[_document year]];
	[result setAlbumGenre:[_document genre]];
	[result setAlbumComposer:[_document composer]];
	[result setAlbumComment:[_document comment]];
		
	[result setDiscNumber:[_document discNumber]];
	[result setDiscsInSet:[_document discsInSet]];
	[result setMultipleArtists:[_document multiArtist]];

	[result setAlbumArt:[_document valueForKey:@"albumArtBitmap"]];
	
	[result setMCN:[_document MCN]];
	
	return [result autorelease];
}

- (void) clearFreeDBData
{
	[self setTitle:nil];
	[self setArtist:nil];
	[self setYear:0];
	[self setGenre:nil];
}

@end
