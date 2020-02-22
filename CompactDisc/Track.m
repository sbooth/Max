/*
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

#import "Track.h"
#import "CompactDiscDocument.h"

#include <IOKit/storage/IOCDTypes.h>

@interface Track (Private)
- (NSUndoManager *) undoManager;
@end

@implementation Track

+ (NSSet *) keyPathsForValuesAffectingMinute
{
	return [NSSet setWithObjects:@"firstSector", @"lastSector", nil];
}

+ (NSSet *) keyPathsForValuesAffectingSecond
{
	return [NSSet setWithObjects:@"firstSector", @"lastSector", nil];
}

+ (NSSet *) keyPathsForValuesAffectingFrame
{
	return [NSSet setWithObjects:@"firstSector", @"lastSector", nil];
}

+ (NSSet *) keyPathsForValuesAffectingSize
{
	return [NSSet setWithObjects:@"firstSector", @"lastSector", nil];
}

+ (NSSet *) keyPathsForValuesAffectingLength
{
	return [NSSet setWithObjects:@"firstSector", @"lastSector", nil];
}

+ (NSSet *) keyPathsForValuesAffectingDuration
{
	return [NSSet setWithObjects:@"firstSector", @"lastSector", nil];
}

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (void) dealloc
{
	[_document release];		_document = nil;
	
	[_title release];			_title = nil;
	[_artist release];			_artist = nil;
	[_date release];			_date = nil;
	[_genre release];			_genre = nil;
	[_composer release];		_composer = nil;
	
	[_musicbrainzTrackId release];  _musicbrainzTrackId = nil;
	[_musicbrainzArtistId release]; _musicbrainzArtistId = nil;
	
	[_ISRC release];			_ISRC = nil;
	
	
	[super dealloc];
}

- (NSString *) description
{
	NSString			*discArtist			= [[self document] artist];
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
	
	
	if([[self document] compilation]) {
		return [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
	}
	else {
		return [NSString stringWithFormat:@"%@", trackTitle];		
	}
}

#pragma mark Accessors

- (NSUInteger) minute
{
	NSUInteger	sector		= [self firstSector];
	NSUInteger	offset		= [self lastSector] - sector + 1;
	
	return (NSUInteger) (offset / (60 * 75));
}

- (NSUInteger) second
{
	NSUInteger	sector		= [self firstSector];
	NSUInteger	offset		= [self lastSector] - sector + 1;
	
	return (NSUInteger) ((offset / 75) % 60);
}

- (NSUInteger) frame
{
	NSUInteger	sector		= [self firstSector];
	NSUInteger	offset		= [self lastSector] - sector + 1;
	
	return (NSUInteger) (offset % 75);
}

- (NSString *)				length				{ return [NSString stringWithFormat:@"%lu:%02lu", (unsigned long)[self minute], (unsigned long)[self second]]; }
- (CompactDiscDocument *)	document			{ return [[_document retain] autorelease]; }

- (BOOL)					ripInProgress		{ return _ripInProgress; }
- (BOOL)					encodeInProgress	{ return (0 != _activeEncoders); }

- (BOOL)					selected			{ return _selected; }

- (NSString *)				title				{ return [[_title retain] autorelease]; }
- (NSString *)				artist				{ return [[_artist retain] autorelease]; }
- (NSString *)				date				{ return [[_date retain] autorelease]; }
- (NSString *)				genre				{ return [[_genre retain] autorelease]; }
- (NSString *)				composer			{ return [[_composer retain] autorelease]; }
- (NSString *)				comment				{ return [[_comment retain] autorelease]; }

- (NSUInteger)				byteSize			{ return (([self lastSector] - [self firstSector]) * kCDSectorSizeCDDA); }

- (NSString *)				musicbrainzTrackId	{ return [[_musicbrainzTrackId retain] autorelease]; }
- (NSString *)				musicbrainzArtistId	{ return [[_musicbrainzArtistId retain] autorelease]; }

- (NSUInteger)				number				{ return _number; }
- (NSUInteger)				firstSector			{ return _firstSector; }
- (NSUInteger)				lastSector			{ return _lastSector; }
- (NSUInteger)				channels			{ return _channels; }
- (BOOL)					preEmphasis			{ return _preEmphasis; }
- (BOOL)					copyPermitted		{ return _copyPermitted; }
- (NSString *)				ISRC				{ return [[_ISRC retain] autorelease]; }
- (BOOL)					dataTrack			{ return _dataTrack; }

#pragma mark Mutators

- (void) setDocument:(CompactDiscDocument *)document	{ [_document release]; _document = [document retain]; }

- (void) setRipInProgress:(BOOL)ripInProgress			{ _ripInProgress = ripInProgress; }

- (void) setSelected:(BOOL)selected						{ _selected = selected; }

- (void) setMusicbrainzTrackId:(NSString *)musicbrainzTrackId
{ [_musicbrainzTrackId release]; _musicbrainzTrackId = [musicbrainzTrackId retain]; }
- (void) setMusicbrainzArtistId:(NSString *)musicbrainzArtistId
{ [_musicbrainzArtistId release]; _musicbrainzArtistId = [musicbrainzArtistId retain]; }

- (void) setNumber:(NSUInteger)number					{ _number = number; }
- (void) setFirstSector:(NSUInteger)firstSector			{ _firstSector = firstSector; }
- (void) setLastSector:(NSUInteger)lastSector			{ _lastSector = lastSector; }
- (void) setChannels:(NSUInteger)channels				{ _channels = channels; }
- (void) setPreEmphasis:(BOOL)preEmphasis				{ _preEmphasis = preEmphasis; }
- (void) setCopyPermitted:(BOOL)copyPermitted			{ _copyPermitted = copyPermitted; }
- (void) setISRC:(NSString *)ISRC						{ [_ISRC release]; _ISRC = [ISRC retain]; }
- (void) setDataTrack:(BOOL)dataTrack					{ _dataTrack = dataTrack; }

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
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Title", @"UndoRedo", @"")];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [_artist isEqualToString:artist]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setArtist:) object:_artist];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Artist", @"UndoRedo", @"")];
		[_artist release];
		_artist = [artist retain];
	}
}

- (void) setDate:(NSString *)date
{
	if(_date != date) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDate:) object:_date];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Date", @"UndoRedo", @"")];
		[_date release];
		_date = [date retain];
	}
}

- (void) setGenre:(NSString *)genre
{
	if(NO == [_genre isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Genre", @"UndoRedo", @"")];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [_composer isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Composer", @"UndoRedo", @"")];
		[_composer release];
		_composer = [composer retain];
	}
}

- (void) setComment:(NSString *)comment
{
	if(NO == [_comment isEqualToString:comment]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComment:) object:_comment];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track Comment", @"UndoRedo", @"")];
		[_comment release];
		_comment = [comment retain];
	}
}

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:10];
	
//	[result setObject:[NSNumber numberWithBool:[self selected]] forKey:@"selected"];

	[result setValue:[self title] forKey:@"title"];
	[result setValue:[self artist] forKey:@"artist"];
	[result setValue:[self date] forKey:@"date"];
	[result setValue:[self genre] forKey:@"genre"];
	[result setValue:[self composer] forKey:@"composer"];
	[result setValue:[self comment] forKey:@"comment"];

	[result setValue:[self musicbrainzTrackId] forKey:@"musicbrainzTrackId"];
	[result setValue:[self musicbrainzArtistId] forKey:@"musicbrainzArtistId"];

	[result setObject:[NSNumber numberWithUnsignedInteger:[self number]] forKey:@"number"];
	[result setObject:[NSNumber numberWithUnsignedInteger:[self firstSector]] forKey:@"firstSector"];
	[result setObject:[NSNumber numberWithUnsignedInteger:[self lastSector]] forKey:@"lastSector"];
	[result setObject:[NSNumber numberWithUnsignedInteger:[self channels]] forKey:@"channels"];
	[result setObject:[NSNumber numberWithBool:[self preEmphasis]] forKey:@"preEmphasis"];
	[result setObject:[NSNumber numberWithBool:[self copyPermitted]] forKey:@"copyPermitted"];
	[result setValue:[self ISRC] forKey:@"ISRC"];
	[result setObject:[NSNumber numberWithBool:[self dataTrack]] forKey:@"dataTrack"];
	
	return [[result retain] autorelease];
}

- (void) setPropertiesFromDictionary:(NSDictionary *)properties
{	
	[_title release];		_title = nil;
	[_artist release];		_artist = nil;
	[_date release];		_date = nil;
	[_genre release];		_genre = nil;
	[_composer release];	_composer = nil;
	[_comment release];		_comment = nil;
	
	[_musicbrainzTrackId release];	_musicbrainzTrackId = nil;
	[_musicbrainzArtistId release];	_musicbrainzArtistId = nil;
	
	[_ISRC release];		_ISRC = nil;

//	_selected		= [[properties valueForKey:@"selected"] boolValue];

	_title			= [[properties valueForKey:@"title"] retain];
	_artist			= [[properties valueForKey:@"artist"] retain];
	_date			= [[properties valueForKey:@"date"] retain];
	_genre			= [[properties valueForKey:@"genre"] retain];
	_composer		= [[properties valueForKey:@"composer"] retain];
	_comment		= [[properties valueForKey:@"comment"] retain];

	_musicbrainzTrackId		= [[properties valueForKey:@"musicbrainzTrackId"] retain];
	_musicbrainzArtistId	= [[properties valueForKey:@"musicbrainzArtistId"] retain];

	_number			= [[properties valueForKey:@"number"] unsignedIntValue];
	_firstSector	= [[properties valueForKey:@"firstSector"] unsignedIntegerValue];
	_lastSector		= [[properties valueForKey:@"lastSector"] unsignedIntegerValue];
	_channels		= [[properties valueForKey:@"channels"] unsignedIntValue];
	_preEmphasis	= [[properties valueForKey:@"preEmphasis"] boolValue];
	_copyPermitted	= [[properties valueForKey:@"copyPermitted"] boolValue];
	_ISRC			= [[properties valueForKey:@"ISRC"] retain];
	_dataTrack		= [[properties valueForKey:@"dataTrack"] boolValue];
	
	// Maintain backwards compatibility
	if(nil == _date && nil != [properties valueForKey:@"year"] && 0 != [[properties valueForKey:@"year"] intValue])
		_date		= [[[properties valueForKey:@"year"] stringValue] retain];
}

- (id) copyWithZone:(NSZone *)zone
{
	Track *copy = [[Track allocWithZone:zone] init];
	
	[copy setDocument:[self document]];
	
	[copy setSelected:[self selected]];
	
	[copy setTitle:[self title]];
	[copy setArtist:[self artist]];
	[copy setDate:[self date]];
	[copy setGenre:[self genre]];
	[copy setComposer:[self composer]];
	[copy setComment:[self comment]];

	[copy setMusicbrainzTrackId:[self musicbrainzTrackId]];
	[copy setMusicbrainzArtistId:[self musicbrainzArtistId]];
	
	[copy setNumber:[self number]];
	[copy setFirstSector:[self firstSector]];
	[copy setLastSector:[self lastSector]];
	[copy setChannels:[self channels]];
	[copy setPreEmphasis:[self preEmphasis]];
	[copy setCopyPermitted:[self copyPermitted]];
	[copy setISRC:[self ISRC]];
	[copy setDataTrack:[self dataTrack]];

	return copy;
}

- (AudioMetadata *) metadata
{
	AudioMetadata *result = [[AudioMetadata alloc] init];

	[result setTrackNumber:[NSNumber numberWithUnsignedInteger:[self number]]];
	[result setTrackTitle:[self title]];
	[result setTrackArtist:[self artist]];
	[result setTrackDate:[self date]];
	[result setTrackGenre:[self genre]];
	[result setTrackComposer:[self composer]];
	[result setTrackComment:[self comment]];
	[result setISRC:[self ISRC]];
	
	[result setTrackTotal:[NSNumber numberWithUnsignedInteger:[[self document] countOfTracks]]];
	[result setAlbumTitle:[[self document] title]];
	[result setAlbumArtist:[[self document] artist]];
	[result setAlbumDate:[[self document] date]];
	[result setAlbumGenre:[[self document] genre]];
	[result setAlbumComposer:[[self document] composer]];
	[result setAlbumComment:[[self document] comment]];
	
	[result setMusicbrainzTrackId: [self musicbrainzTrackId]];
	[result setMusicbrainzArtistId: [self musicbrainzArtistId]];
	[result setMusicbrainzAlbumId: [[self document] musicbrainzAlbumId]];
	[result setMusicbrainzAlbumArtistId: [[self document] musicbrainzArtistId]];
	
	[result setDiscNumber:[[self document] discNumber]];
	[result setDiscTotal:[[self document] discTotal]];
	[result setCompilation:[[self document] compilation]];

	[result setAlbumArt:[[self document] albumArt]];
	
	[result setDiscId:[[self document] discID]];
	[result setMCN:[[self document] MCN]];
	
	return [result autorelease];
}

#pragma mark Scripting

- (NSScriptObjectSpecifier *) objectSpecifier
{
    NSArray		*tracks		= [[self document] valueForKey:@"tracks"];
    NSUInteger	idx			= [tracks indexOfObjectIdenticalTo:self];

    if(NSNotFound != idx) {
        NSScriptObjectSpecifier *containerRef = [[self document] objectSpecifier];
        return [[[NSIndexSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"tracks" index:idx] autorelease];
    }
	else {
        return nil;
    }
}

@end

@implementation Track (Private)
- (NSUndoManager *)			undoManager			{ return [[self document] undoManager]; }
@end
