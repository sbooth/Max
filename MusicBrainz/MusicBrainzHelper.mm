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

#import "MusicBrainzHelper.h"

#include <musicbrainz5/Query.h>
#include <musicbrainz5/Release.h>
#include <musicbrainz5/Artist.h>
#include <musicbrainz5/ArtistCredit.h>
#include <musicbrainz5/NameCredit.h>
#include <musicbrainz5/Medium.h>
#include <musicbrainz5/Track.h>
#include <musicbrainz5/Recording.h>
#include <musicbrainz5/RelationListList.h>
#include <musicbrainz5/RelationList.h>
#include <musicbrainz5/Relation.h>
#include <musicbrainz5/HTTPFetch.h>

#import "CompactDiscDocument.h"

@interface MusicBrainzHelper (Private)
- (NSString *) discID;
@end

@implementation MusicBrainzHelper

- (id) initWithDiscID:(NSString *)discID
{
	NSParameterAssert(nil != discID);
	
	if((self = [super init])) {
		_matches = [[NSMutableArray alloc] init];
		_discID = [discID retain];
	}

	return self;
}

- (void) dealloc
{
	[_matches release];	_matches = nil;
	[_discID release];	_discID = nil;
	
	[super dealloc];
}

- (IBAction) performQuery:(id)sender
{
	// Set MB server and port
	NSString *server = @"musicbrainz.org";
	if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"]) {
		server = [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"];
	}

	int port = 80;
	if(nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzServerPort"]) {
		port = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzServerPort"];
	}

	NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	auto query = MusicBrainz5::CQuery([[NSString stringWithFormat:@"Max %@", bundleVersion] UTF8String], [server UTF8String], port);

	// Use authentication, if specified
	if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"]) {
		query.SetUserName([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"] UTF8String]);
	}

	if(nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzPassword"]) {
		query.SetPassword([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzPassword"] UTF8String]);
	}

	// Proxy setup
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"musicBrainzUseProxy"]) {
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"]) {
			query.SetProxyHost([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"] UTF8String]);
		}
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServerPort"]) {
			query.SetProxyPort((int)[[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzProxyServerPort"]);
		}
	}

	[_matches removeAllObjects];
	
	try {
		auto releaseList = query.LookupDiscID([[self discID] UTF8String]);

		for(auto i = 0; i < releaseList.NumItems(); i++) {
			auto rel = releaseList.Item(i);

			MusicBrainz5::CQuery::tParamMap params;
			params["inc"] = "artists labels recordings release-groups url-rels discids artist-credits isrcs";

			auto metadata = query.Query("release", rel->ID(), "", params);
			if(metadata.Release()) {
				auto release = metadata.Release();

				NSMutableDictionary *releaseDictionary = [NSMutableDictionary dictionary];

				// ID
				if(!release->ID().empty()) {
					[releaseDictionary setValue:[NSString stringWithCString:release->ID().c_str() encoding:NSUTF8StringEncoding] forKey:@"albumId"];
				}

				// Title
				if(!release->Title().empty()) {
					[releaseDictionary setValue:[NSString stringWithCString:release->Title().c_str() encoding:NSUTF8StringEncoding] forKey:@"title"];
				}

				// Artist
				if(nullptr != release->ArtistCredit()) {
					auto nameCreditList = release->ArtistCredit()->NameCreditList();
					// TODO: Is it appropriate to just use the first entry?
					if(nullptr != nameCreditList && 0 < nameCreditList->NumItems()) {
						auto nameCredit = nameCreditList->Item(0);
						if(nullptr != nameCredit->Artist()) {
							auto artist = nameCredit->Artist();
							if(!artist->Name().empty()) {
								[releaseDictionary setValue:[NSString stringWithCString:artist->Name().c_str() encoding:NSUTF8StringEncoding] forKey:@"artist"];
								[releaseDictionary setValue:[NSString stringWithCString:artist->ID().c_str() encoding:NSUTF8StringEncoding] forKey:@"artistId"];
							}
						}
					}
				}

				// TODO: Iterate through the release group and search for the most applicable country code?

				// Release date
				if(!release->Date().empty()) {
					[releaseDictionary setValue:[NSString stringWithCString:release->Date().c_str() encoding:NSUTF8StringEncoding] forKey:@"date"];
				}

				// Iterate through the tracks
				NSMutableArray *tracksDictionary = [NSMutableArray array];

				// TODO: Use MediaMatchingDiscID()?
				auto mediumList = release->MediumList();
				// TODO: Is it appropriate to just use the first entry?
				if(nullptr != mediumList && 0 < mediumList->NumItems()) {
					auto medium = mediumList->Item(0);

					auto trackList = medium->TrackList();
					if(nullptr != trackList) {
						for(auto k = 0; k < trackList->NumItems(); k++) {
							auto track = trackList->Item(k);

							NSMutableDictionary *trackDictionary = [NSMutableDictionary dictionary];

							// Number
							[trackDictionary setValue:[NSNumber numberWithInt:track->Position()] forKey:@"trackNumber"];

							auto recording = track->Recording();
							if(nullptr != recording) {
								// ID
								if(!recording->ID().empty()) {
									[trackDictionary setValue:[NSString stringWithCString:recording->ID().c_str() encoding:NSUTF8StringEncoding] forKey:@"trackId"];
								}

								// Track title
								[trackDictionary setValue:[NSString stringWithCString:recording->Title().c_str() encoding:NSUTF8StringEncoding] forKey:@"title"];

								// Track artist
								if(nullptr != recording->ArtistCredit()) {
									auto nameCreditList = recording->ArtistCredit()->NameCreditList();
									// TODO: Is it appropriate to just use the first entry?
									if(nullptr != nameCreditList && 0 < nameCreditList->NumItems()) {
										auto nameCredit = nameCreditList->Item(0);
										if(nullptr != nameCredit->Artist()) {
											auto artist = nameCredit->Artist();
											if(!artist->Name().empty()) {
												[trackDictionary setValue:[NSString stringWithCString:artist->Name().c_str() encoding:NSUTF8StringEncoding] forKey:@"artist"];
												[trackDictionary setValue:[NSString stringWithCString:artist->ID().c_str() encoding:NSUTF8StringEncoding] forKey:@"artistId"];
											}
										}
									}
								}
							}

							// FIXME
							// Look for Composer relations
							auto relationLists = recording->RelationListList();
							if(nullptr != relationLists) {
								for(auto m = 0; m < relationLists->NumItems(); ++m) {
									auto relationList = relationLists->Item(m);
									std::cout << relationList << std::endl;
									if(nullptr != relationList && 0 < relationList->NumItems() && "composer" == relationList->TargetType()) {
//										auto composerList = relationList->Item(0);
//										[trackDictionary setValue:[NSString stringWithCString:XXXXX().c_str() encoding:NSUTF8StringEncoding] forKey:@"composer"];
									}
								}
							}

							[tracksDictionary addObject:trackDictionary];
						}
					}
				}

				[releaseDictionary setValue:tracksDictionary forKey:@"tracks"];
				[_matches addObject:releaseDictionary];
			}
		}
	}
	
	catch(const MusicBrainz5::CExceptionBase &e) {
		NSLog(@"Error: %s", e.what());
		return;
	}
}

- (NSUInteger) matchCount
{
	return [_matches count];
}

- (NSDictionary *) matchAtIndex:(NSUInteger)matchIndex;
{
	return [_matches objectAtIndex:matchIndex];
}

@end

@implementation MusicBrainzHelper (Private)
- (MusicBrainzHelperData *)		data		{ return [[_data retain] autorelease]; }
- (NSString *)					discID		{ return [[_discID retain] autorelease]; }
@end
