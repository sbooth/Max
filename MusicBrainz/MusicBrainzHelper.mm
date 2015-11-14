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

#include <musicbrainz3/webservice.h>
#include <musicbrainz3/query.h>
#include <musicbrainz3/model.h>
#include <musicbrainz3/utils.h>

#import "CompactDiscDocument.h"

// This is here to avoid C++ code cascading into what otherwise is mostly Objective-C
@interface MusicBrainzHelperData : NSObject
{
	MusicBrainz::WebService *_ws;
}

- (MusicBrainz::WebService *) ws;

@end

@implementation MusicBrainzHelperData

- (id) init
{
	if((self = [super init])) {
		_ws = new MusicBrainz::WebService();
		if(NULL == _ws) {
			[self release];
			return nil;
		}
		
		// Set MB server and port
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"])
			_ws->setHost([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"] cStringUsingEncoding:NSUTF8StringEncoding]);
		
		if(nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzServerPort"])
			_ws->setPort([[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzServerPort"]);
		
		// Use authentication, if specified
		if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"])
			_ws->setUserName([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzUsername"] cStringUsingEncoding:NSUTF8StringEncoding]);
		
		if(nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzPassword"])
			_ws->setPassword([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzPassword"] cStringUsingEncoding:NSUTF8StringEncoding]);

		// Proxy setup
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"musicBrainzUseProxy"]) {
			if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"])
				_ws->setProxyHost([[[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServer"] cStringUsingEncoding:NSUTF8StringEncoding]);
			if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzProxyServerPort"])
				_ws->setProxyPort([[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzProxyServerPort"]);
		}		
	}
	
	return self;
}

- (void) dealloc
{
	delete _ws, _ws = NULL;
	
	[super dealloc];
}

- (MusicBrainz::WebService *) ws { return _ws; }

@end


@interface MusicBrainzHelper (Private)
- (MusicBrainzHelperData *) data;
- (NSString *) discID;
@end

@implementation MusicBrainzHelper

- (id) initWithDiscID:(NSString *)discID
{
	NSParameterAssert(nil != discID);
	
	if((self = [super init])) {
		
		_matches = [[NSMutableArray alloc] init];
		
		_data = [[MusicBrainzHelperData alloc] init];
		if(nil == _data) {
			[self release];
			return nil;
		}

		_discID = [discID retain];
	}

	return self;
}

- (void) dealloc
{
	[_matches release],		_matches = nil;
	[_data release],		_data = nil;
	[_discID release],		_discID = nil;
	
	[super dealloc];
}

- (IBAction) performQuery:(id)sender
{
	MusicBrainz::Query					q([[self data] ws]);
	MusicBrainz::ReleaseResultList		results;
	
	[_matches removeAllObjects];
	
	try {
		std::string discId = [[self discID] cStringUsingEncoding:NSASCIIStringEncoding];
		MusicBrainz::ReleaseFilter f = MusicBrainz::ReleaseFilter().discId(discId);
        results = q.getReleases(&f);
	}
	
	catch(/* const MusicBrainz::Exception &e */const std::exception &e) {
		NSLog(@"Error: %s", e.what());
		return;
	}
	
	for(MusicBrainz::ReleaseResultList::iterator i = results.begin(); i != results.end(); i++) {
		MusicBrainz::ReleaseResult *result = *i;
		MusicBrainz::Release *release;
		
		try {
			MusicBrainz::ReleaseIncludes includes = MusicBrainz::ReleaseIncludes().tracks().artist().releaseEvents();
			release = q.getReleaseById(result->getRelease()->getId(), &includes);
		}
		
		catch(/* const MusicBrainz::Exception &e */const std::exception &e) {
			NSLog(@"Error: %s", e.what());
			continue;
		}

		NSMutableDictionary *releaseDictionary = [NSMutableDictionary dictionary];

		// ID
		if(!release->getId().empty())
			[releaseDictionary setValue:[NSString stringWithCString:release->getId().c_str() encoding:NSUTF8StringEncoding] forKey:@"albumId"];

		// Title
		if(!release->getTitle().empty())
			[releaseDictionary setValue:[NSString stringWithCString:release->getTitle().c_str() encoding:NSUTF8StringEncoding] forKey:@"title"];

		// Artist
		if(NULL != release->getArtist() && !release->getArtist()->getName().empty()) {
			[releaseDictionary setValue:[NSString stringWithCString:release->getArtist()->getName().c_str() encoding:NSUTF8StringEncoding] forKey:@"artist"];
			[releaseDictionary setValue:[NSString stringWithCString:release->getArtist()->getId().c_str() encoding:NSUTF8StringEncoding] forKey:@"artistId"];
		}
		
		// Take a best guess on the release date
		if(1 == release->getNumReleaseEvents()) {
			MusicBrainz::ReleaseEvent *releaseEvent = release->getReleaseEvent(0);
			[releaseDictionary setValue:[NSString stringWithCString:releaseEvent->getDate().c_str() encoding:NSUTF8StringEncoding] forKey:@"date"];
		}
		else {
			NSString	*currentLocale		= [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLocale"];
			NSArray		*localeElements		= [currentLocale componentsSeparatedByString:@"_"];
//			NSString	*currentLanguage	= [localeElements objectAtIndex:0];
			NSString	*currentCountry		= [localeElements objectAtIndex:1];
			
			// Try to match based on the assumption that the disc is from the user's own locale
			for(int k = 0; k < release->getNumReleaseEvents(); ++k) {
				MusicBrainz::ReleaseEvent *releaseEvent = release->getReleaseEvent(k);
				NSString *releaseEventCountry = [NSString stringWithCString:releaseEvent->getCountry().c_str() encoding:NSASCIIStringEncoding];
				if(NSOrderedSame == [releaseEventCountry caseInsensitiveCompare:currentCountry])
					[releaseDictionary setValue:[NSString stringWithCString:releaseEvent->getDate().c_str() encoding:NSUTF8StringEncoding] forKey:@"date"];
			}
			
			// Nothing matched, just take the first one
			if(nil == [releaseDictionary valueForKey:@"date"] && 0 < release->getNumReleaseEvents()) {
				MusicBrainz::ReleaseEvent *releaseEvent = release->getReleaseEvent(0);
				[releaseDictionary setValue:[NSString stringWithCString:releaseEvent->getDate().c_str() encoding:NSUTF8StringEncoding] forKey:@"date"];
			}
		}

		// Iterate through the tracks
		NSMutableArray *tracksDictionary = [NSMutableArray array];
		int trackno = 1;
		for(MusicBrainz::TrackList::iterator j = release->getTracks().begin(); j != release->getTracks().end(); j++) {
			MusicBrainz::Track *track = *j;
			NSMutableDictionary *trackDictionary = [NSMutableDictionary dictionary];

			// Number
			[trackDictionary setValue:[NSNumber numberWithInt:trackno] forKey:@"trackNumber"];

			// ID
			if(!track->getId().empty())
				[trackDictionary setValue:[NSString stringWithCString:track->getId().c_str() encoding:NSUTF8StringEncoding] forKey:@"trackId"];

			// Track title
			[trackDictionary setValue:[NSString stringWithCString:track->getTitle().c_str() encoding:NSUTF8StringEncoding] forKey:@"title"];

			// Track artist
			if(NULL != track->getArtist() && !track->getArtist()->getName().empty()) {
				[trackDictionary setValue:[NSString stringWithCString:track->getArtist()->getName().c_str() encoding:NSUTF8StringEncoding] forKey:@"artist"];
				[trackDictionary setValue:[NSString stringWithCString:track->getArtist()->getId().c_str() encoding:NSUTF8StringEncoding] forKey:@"artistId"];
			}
			
			// Look for Composer relations
			MusicBrainz::RelationList relations = track->getRelations(MusicBrainz::Relation::TO_TRACK);
			
			for(MusicBrainz::RelationList::iterator k = relations.begin(); k != relations.end(); ++k) {
				MusicBrainz::Relation *relation = *k;
				
				if("Composer" == MusicBrainz::extractFragment(relation->getType())) {
					if(MusicBrainz::Relation::TO_ARTIST == relation->getTargetType()) {
						MusicBrainz::Artist *composer = NULL;
						
						try {
							composer = q.getArtistById(relation->getTargetId());
							if(NULL == composer)
								continue;
						}
						
						catch(/* const MusicBrainz::Exception &e */ const std::exception &e) {
							NSLog(@"MusicBrainz error: %s", e.what());
							continue;
						}
						
						[trackDictionary setValue:[NSString stringWithCString:composer->getName().c_str() encoding:NSUTF8StringEncoding] forKey:@"composer"];
						
						delete composer;
					}
				}				
			}
			
			++trackno;

			[tracksDictionary addObject:trackDictionary];
			delete track;
		}
		
		[releaseDictionary setValue:tracksDictionary forKey:@"tracks"];
		[_matches addObject:releaseDictionary];
		
		delete result;
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
