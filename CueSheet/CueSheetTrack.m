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

#import "CueSheetTrack.h"
#import "CueSheetDocument.h"

#include <IOKit/storage/IOCDTypes.h>

@interface CueSheetTrack (Private)
- (NSUndoManager *) undoManager;
@end

@implementation CueSheetTrack

+ (NSSet *) keyPathsForValuesAffectingLength
{
	return [NSSet setWithObjects:@"startingFrame", @"frameCount", nil];
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
		if(nil == artist)
			artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
	}
	if(nil == trackTitle)
		trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		
	if([[self document] compilation])
		return [NSString stringWithFormat:@"%@ - %@", artist, trackTitle];
	else
		return [NSString stringWithFormat:@"%@", trackTitle];		
}

#pragma mark Accessors

- (NSString *) length
{
	unsigned durationInSeconds = (unsigned)([self frameCount] / [self sampleRate]);
	return [NSString stringWithFormat:@"%i:%02i", durationInSeconds / 60, durationInSeconds % 60];
}

- (CueSheetDocument *)		document			{ return [[_document retain] autorelease]; }

- (BOOL)					selected			{ return _selected; }

- (NSString *)				filename			{ return [[_filename retain] autorelease]; }
- (NSString *)				title				{ return [[_title retain] autorelease]; }
- (NSString *)				artist				{ return [[_artist retain] autorelease]; }
- (NSString *)				date				{ return [[_date retain] autorelease]; }
- (NSString *)				genre				{ return [[_genre retain] autorelease]; }
- (NSString *)				composer			{ return [[_composer retain] autorelease]; }
- (NSString *)				comment				{ return [[_comment retain] autorelease]; }

- (NSUInteger)				number				{ return _number; }
- (Float32)					sampleRate			{ return _sampleRate; }
- (SInt64)					startingFrame		{ return _startingFrame; }
- (UInt32)					frameCount			{ return _frameCount; }
- (NSString *)				ISRC				{ return [[_ISRC retain] autorelease]; }
- (NSUInteger)				preGap				{ return _preGap; }
- (NSUInteger)				postGap				{ return _postGap; }

#pragma mark Mutators

- (void) setDocument:(CueSheetDocument *)document		{ [_document release]; _document = [document retain]; }
- (void) setFilename:(NSString *)filename				{ [_filename release]; _filename = [filename retain]; }

- (void) setSelected:(BOOL)selected						{ _selected = selected; }
- (void) setNumber:(NSUInteger)number
{
	NSParameterAssert(1 <= number && number <= 99);
	_number = number;
}

- (void) setSampleRate:(Float32)sampleRate				{ _sampleRate = sampleRate; }
- (void) setStartingFrame:(SInt64)startingFrame			{ _startingFrame = startingFrame; }
- (void) setFrameCount:(UInt32)frameCount				{ _frameCount = frameCount; }
- (void) setPreGap:(NSUInteger)preGap					{ _preGap = preGap; }
- (void) setPostGap:(NSUInteger)postGap					{ _postGap = postGap; }

- (void) setISRC:(NSString *)ISRC
{
	if(NO == [_ISRC isEqualToString:ISRC]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setISRC:) object:_ISRC];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Track ISRC", @"UndoRedo", @"")];
		[_ISRC release];
		_ISRC = [ISRC retain];
	}
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
	
	[result setObject:[NSNumber numberWithUnsignedInteger:[self number]] forKey:@"number"];
//	[result setObject:[NSNumber numberWithUnsignedLong:[self firstSector]] forKey:@"firstSector"];
//	[result setObject:[NSNumber numberWithUnsignedLong:[self lastSector]] forKey:@"lastSector"];
//	[result setObject:[NSNumber numberWithUnsignedInt:[self channels]] forKey:@"channels"];
//	[result setObject:[NSNumber numberWithBool:[self preEmphasis]] forKey:@"preEmphasis"];
//	[result setObject:[NSNumber numberWithBool:[self copyPermitted]] forKey:@"copyPermitted"];
	[result setValue:[self ISRC] forKey:@"ISRC"];
//	[result setObject:[NSNumber numberWithBool:[self dataTrack]] forKey:@"dataTrack"];
	
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
	
	[_ISRC release];		_ISRC = nil;
	
	//	_selected		= [[properties valueForKey:@"selected"] boolValue];
	
	_title			= [[properties valueForKey:@"title"] retain];
	_artist			= [[properties valueForKey:@"artist"] retain];
	_date			= [[properties valueForKey:@"date"] retain];
	_genre			= [[properties valueForKey:@"genre"] retain];
	_composer		= [[properties valueForKey:@"composer"] retain];
	_comment		= [[properties valueForKey:@"comment"] retain];
	
	_number			= [[properties valueForKey:@"number"] unsignedIntValue];
//	_firstSector	= [[properties valueForKey:@"firstSector"] unsignedLongValue];
//	_lastSector		= [[properties valueForKey:@"lastSector"] unsignedLongValue];
//	_channels		= [[properties valueForKey:@"channels"] unsignedIntValue];
//	_preEmphasis	= [[properties valueForKey:@"preEmphasis"] boolValue];
//	_copyPermitted	= [[properties valueForKey:@"copyPermitted"] boolValue];
	_ISRC			= [[properties valueForKey:@"ISRC"] retain];
//	_dataTrack		= [[properties valueForKey:@"dataTrack"] boolValue];
}

- (id) copyWithZone:(NSZone *)zone
{
	CueSheetTrack *copy = [[CueSheetTrack allocWithZone:zone] init];
	
	[copy setDocument:[self document]];
	
	[copy setSelected:[self selected]];
	
	[copy setTitle:[self title]];
	[copy setArtist:[self artist]];
	[copy setDate:[self date]];
	[copy setGenre:[self genre]];
	[copy setComposer:[self composer]];
	[copy setComment:[self comment]];
	
	[copy setNumber:[self number]];
//	[copy setFirstSector:[self firstSector]];
//	[copy setLastSector:[self lastSector]];
//	[copy setChannels:[self channels]];
//	[copy setPreEmphasis:[self preEmphasis]];
//	[copy setCopyPermitted:[self copyPermitted]];
	[copy setISRC:[self ISRC]];
//	[copy setDataTrack:[self dataTrack]];
	
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
	
	[result setDiscNumber:[[self document] discNumber]];
	[result setDiscTotal:[[self document] discTotal]];
	[result setCompilation:[[self document] compilation]];
	
	[result setAlbumArt:[[self document] albumArt]];
	
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
	else
        return nil;
}

@end

@implementation CueSheetTrack (Private)
- (NSUndoManager *)			undoManager			{ return [[self document] undoManager]; }
@end
