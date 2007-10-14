/*
 *  $Id$
 *
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

#import "MusicBrainzHelper.h"

#include <iostream>
#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/model.h>

//#import "CompactDiscDocument.h"

// This is here to avoid C++ code cascading into what otherwise is mostly Objective-C
@interface MusicBrainzHelperData : NSObject
{
}

//- (MusicBrainz *)	mb;

@end

@implementation MusicBrainzHelperData

- (id) init
{
	if((self = [super init])) {
		
//		_mb = new MusicBrainz();
//		NSAssert(NULL != _mb, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
//		[self mb]->UseUTF8(true);

		// Set MB server and port
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"] && nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzServerPort"]) {
//			[self mb]->SetServer([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"] cStringUsingEncoding:NSUTF8StringEncoding],
//								 [[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzServerPort"]);
		}
		
		// Use authentication, if specified
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"] && nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzPassword"]) {
//			[self mb]->Authenticate([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"] cStringUsingEncoding:NSUTF8StringEncoding],
//									[[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzPassword"] cStringUsingEncoding:NSUTF8StringEncoding]);
		}

		// Proxy setup
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"musicBrainzUseProxy"] && nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"] && nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzProxyServerPort"]) {
//			[self mb]->SetProxy([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"] cStringUsingEncoding:NSUTF8StringEncoding],
//								[[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzProxyServerPort"]);						
		}
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
//	delete _mb;		_mb = NULL;
	
	[super dealloc];
}

//- (MusicBrainz *)	mb			{ return _mb; }

@end


@interface MusicBrainzHelper (Private)
- (MusicBrainzHelperData *) data;
- (CompactDiscDocument *)	document;
@end

@implementation MusicBrainzHelper

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)document
{
	NSParameterAssert(nil != document);
	
	if((self = [super init])) {
		
		_data = [[MusicBrainzHelperData alloc] init];
		NSAssert(nil != _data, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));

		_document = [document retain];		
		
		return self;
	}

	return nil;
}

- (void) dealloc
{
	[_data release];	_data = nil;
	[_document release],	_document = nil;
	
	[super dealloc];
}

- (IBAction) performQuery:(id)sender
{
	MusicBrainz::Query					q;
	MusicBrainz::ReleaseResultList		results;
	
	try {
		std::string discId = [[[[self document] disc] discID] cStringUsingEncoding:NSASCIIStringEncoding];
		MusicBrainz::ReleaseFilter f = MusicBrainz::ReleaseFilter().discId(discId);
        results = q.getReleases(&f);
	}
	
	catch(MusicBrainz::WebServiceError &e) {
		std::cout << "Error: " << e.what() << std::endl;
		return;// 1;
	}
	
	for(MusicBrainz::ReleaseResultList::iterator i = results.begin(); i != results.end(); i++) {
		MusicBrainz::ReleaseResult *result = *i;
		MusicBrainz::Release *release;

		try {
			release = q.getReleaseById(result->getRelease()->getId(), &MusicBrainz::ReleaseIncludes().tracks().artist());
		}
		
		catch(MusicBrainz::WebServiceError &e) {
			std::cout << "Error: " << e.what() << std::endl;
			continue;
		}
	
		std::cout << "Id      : " << release->getId() << std::endl;
		std::cout << "Title   : " << release->getTitle() << std::endl;
		std::cout << "Tracks  : ";
		int trackno = 1;
		for(MusicBrainz::TrackList::iterator j = release->getTracks().begin(); j != release->getTracks().end(); j++) {
			MusicBrainz::Track *track = *j;
			MusicBrainz::Artist *artist = track->getArtist();
			if (!artist)
				artist = release->getArtist();
			std::cout << trackno++ << ". " << artist->getName() << " / " << track->getTitle() << std::endl;
			std::cout << "          ";
		}
		std::cout << std::endl;
		delete result;
	}
}

- (unsigned) matchCount
{
	return 0;
//	return [[self data] mb]->DataInt(MBE_GetNumAlbums);
}

- (void) selectMatch:(unsigned)matchIndex
{
//	[[self data] mb]->Select(MBS_SelectAlbum, matchIndex);
}

- (NSString *)		albumTitle
{
//	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetAlbumName).c_str() encoding:NSUTF8StringEncoding];
}

- (NSString *)		albumArtist
{
//	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetAlbumArtistName).c_str() encoding:NSUTF8StringEncoding];
}

- (BOOL)			isVariousArtists
{
//	std::string		data;
	
//	[[self data] mb]->GetIDFromURL([[self data] mb]->Data(MBE_AlbumGetAlbumArtistId), data);
//	return (MBI_VARIOUS_ARTIST_ID == data);
}

- (unsigned)		releaseDate
{
//	NSLog(@"release:%s", [[self data] mb]->Data(MBE_ReleaseGetDate).c_str());
//	return 0;
//	return [NSString stringWithCString:[[self data] mb]->Data(MBE_ReleaseGetDate).c_str() encoding:NSUTF8StringEncoding];
}

- (unsigned) trackCount
{
//	return [[self data] mb]->DataInt(MBE_AlbumGetNumTracks);
}

- (NSString *)		trackTitle:(unsigned)trackIndex
{
//	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetTrackName, trackIndex).c_str() encoding:NSUTF8StringEncoding];
}

- (NSString *)		trackArtist:(unsigned)trackIndex
{
//	return [NSString stringWithCString:[[self data] mb]->Data(MBE_AlbumGetArtistName, trackIndex).c_str() encoding:NSUTF8StringEncoding];
}

@end

@implementation MusicBrainzHelper (Private)
- (MusicBrainzHelperData *)		data		{ return [[_data retain] autorelease]; }
- (CompactDiscDocument *)		document	{ return [[_document retain] autorelease]; }
@end
