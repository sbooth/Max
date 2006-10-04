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

#import "MusicBrainzHelper.h"

#include <musicbrainz/diskid.h>
#include <musicbrainz/musicbrainz.h>

// This is here to avoid a C++ code cascading into what otherwise is mostly Objective-C
@interface MusicBrainzHelperData : NSObject
{
	MusicBrainz				*_mb;
	MUSICBRAINZ_CDINFO		_cdInfo;	
}

- (MusicBrainz *)	mb;

@end

@implementation MusicBrainzHelperData

- (id) init
{
	if((self = [super init])) {
		
		_mb = new MusicBrainz();
		NSAssert(NULL != _mb, @"Unable to allocate memory");
		
		[self mb]->UseUTF8(true);

		// Set MB server and port
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"] && nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzServerPort"]) {
			[self mb]->SetServer([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"] cStringUsingEncoding:NSUTF8StringEncoding],
								 [[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzServerPort"]);
		}
		
		// Use authentication, if specified
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"] && nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzPassword"]) {
			[self mb]->Authenticate([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"] cStringUsingEncoding:NSUTF8StringEncoding],
									[[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzPassword"] cStringUsingEncoding:NSUTF8StringEncoding]);
		}

		// Proxy setup
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"musicBrainzUseProxy"] && nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"] && nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzProxyServerPort"]) {
			[self mb]->SetProxy([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"] cStringUsingEncoding:NSUTF8StringEncoding],
								[[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzProxyServerPort"]);						
		}
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	delete _mb;		_mb = NULL;
	
	[super dealloc];
}

- (MusicBrainz *)	mb			{ return _mb; }

@end


@interface MusicBrainzHelper (Private)
- (MusicBrainzHelperData *) data;
- (CompactDisc *)			disc;
@end

@implementation MusicBrainzHelper

- (id) initWithCompactDisc:(CompactDisc *)disc
{
	NSParameterAssert(nil != disc);
	
	if((self = [super init])) {
		
		_data = [[MusicBrainzHelperData alloc] init];
		NSAssert(nil != _data, @"Unable to allocate memory");

		_disc = [disc retain];		
		
		return self;
	}

	return nil;
}

- (void) dealloc
{
	[_data release];	_data = nil;
	[_disc release];	_disc = nil;
	
	[super dealloc];
}

- (NSString *) discID
{
	MUSICBRAINZ_CDINFO	mbCDInfo;
	DiskId				diskID;
	char				idString [33];
	unsigned			i;
	unsigned			session;
	unsigned			firstTrackIndex, lastTrackIndex;
	
	// Fill in the MUSICBRAINZ_CDINFO struct
	memset(&mbCDInfo, 0, sizeof(MUSICBRAINZ_CDINFO));
	
	session					= 1;
	firstTrackIndex			= 0;
	lastTrackIndex			= [[self disc] countOfTracks] - 1;
	
	mbCDInfo.FirstTrack		= [[[[self disc] objectInTracksAtIndex:firstTrackIndex] objectForKey:@"number"] unsignedIntValue];
	mbCDInfo.LastTrack		= [[[[self disc] objectInTracksAtIndex:lastTrackIndex] objectForKey:@"number"] unsignedIntValue];
	
	mbCDInfo.FrameOffset[0]	= [[self disc] leadOut] + 150;
	
	for(i = firstTrackIndex; i <= lastTrackIndex; ++i) {
		mbCDInfo.FrameOffset[i + 1]	= [[self disc] firstSectorForTrack:i] + 150;
	}
	
	diskID.GenerateId(&mbCDInfo, idString);
	
	return [NSString stringWithCString:idString encoding:NSASCIIStringEncoding];
}

- (IBAction) performQuery:(id)sender
{
	MUSICBRAINZ_CDINFO	mbCDInfo;
	DiskId				diskID;
	std::string			query, data, error;
	bool				mbResult;
	unsigned			i;
	unsigned			session;
	unsigned			firstTrackIndex, lastTrackIndex;
	
	// Fill in the MUSICBRAINZ_CDINFO struct
	memset(&mbCDInfo, 0, sizeof(MUSICBRAINZ_CDINFO));
	
	session					= 1;
	firstTrackIndex			= 0;
	lastTrackIndex			= [[self disc] countOfTracks] - 1;
	
	mbCDInfo.FirstTrack		= [[[[self disc] objectInTracksAtIndex:firstTrackIndex] objectForKey:@"number"] unsignedIntValue];
	mbCDInfo.LastTrack		= [[[[self disc] objectInTracksAtIndex:lastTrackIndex] objectForKey:@"number"] unsignedIntValue];
	
	mbCDInfo.FrameOffset[0]	= [[self disc] leadOut] + 150;
	
	for(i = firstTrackIndex; i <= lastTrackIndex; ++i) {
		mbCDInfo.FrameOffset[i + 1]	= [[self disc] firstSectorForTrack:i] + 150;
	}
	
	// Generate the RDF query for the specific CD
	mbResult = diskID.GenerateDiskIdQueryRDF(&mbCDInfo, query, false);
	NSAssert1(kError_NoErr == mbResult, @"GenerateDiskIdQueryRDF failed: %i", mbResult);
	
	// Run the query
	mbResult = [[self data] mb]->Query(query);
	//	NSAssert1(kError_NoErr == mbResult, @"Query failed: %i", mbError);
	if(kError_NoErr != mbResult) {
		[[self data] mb]->GetQueryError(error);
		NSLog(@"Query failed. Error: %s", error.c_str());
	}	
}

- (unsigned) matchCount
{
	return [[self data] mb]->DataInt(MBE_GetNumAlbums);
}

- (void) selectMatch:(unsigned)matchIndex
{
	[[self data] mb]->Select(MBS_SelectAlbum, matchIndex);
}

- (NSString *)		albumTitle
{
	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetAlbumName).c_str() encoding:NSUTF8StringEncoding];
}

- (NSString *)		albumArtist
{
	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetAlbumArtistName).c_str() encoding:NSUTF8StringEncoding];
}

- (BOOL)			isVariousArtists
{
	std::string		data;
	
	[[self data] mb]->GetIDFromURL([[self data] mb]->Data(MBE_AlbumGetAlbumArtistId), data);
	return (MBI_VARIOUS_ARTIST_ID == data);
}

- (unsigned)		releaseDate
{
	NSLog(@"release:%s", [[self data] mb]->Data(MBE_ReleaseGetDate).c_str());
	return 0;
//	return [NSString stringWithCString:[[self data] mb]->Data(MBE_ReleaseGetDate).c_str() encoding:NSUTF8StringEncoding];
}

- (unsigned) trackCount
{
	return [[self data] mb]->DataInt(MBE_AlbumGetNumTracks);
}

- (NSString *)		trackTitle:(unsigned)trackIndex
{
	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetTrackName, trackIndex).c_str() encoding:NSUTF8StringEncoding];
}

- (NSString *)		trackArtist:(unsigned)trackIndex
{
	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetArtistName, trackIndex).c_str() encoding:NSUTF8StringEncoding];
}

@end

@implementation MusicBrainzHelper (Private)
- (MusicBrainzHelperData *)		data		{ return _data; }
- (CompactDisc *)				disc		{ return _disc; }
@end
