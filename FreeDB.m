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

#import "FreeDB.h"

#import "MallocException.h"
#import "FreeDBException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include "cddb/cddb_disc.h"
#include "cddb/cddb.h"

@implementation FreeDB

+ (void) initialize
{
	NSString				*cddbDefaultsValuesPath;
    NSDictionary			*cddbDefaultsValuesDictionary;
    
	@try {
		cddbDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"FreeDBDefaults" ofType:@"plist"];
		if(nil == cddbDefaultsValuesPath) {
			// Hardcode default value to avoid a crash
			NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"freedb.freedb.org", @"8880", @"1", nil] forKeys:[NSArray arrayWithObjects:@"freeDBServer", @"freeDBPort", @"freeDBProtocol", nil]];
			[[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
			@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to load %@", @"Exceptions", @""), @"FreeDBDefaults.plist"] userInfo:nil];
		}
		cddbDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:cddbDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:cddbDefaultsValuesDictionary];
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}
}

- (id) init
{
	NSString *bundleVersion;
	
	if((self = [super init])) {
		
		_freeDB = cddb_new();
		if(NULL == _freeDB) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") userInfo:nil];
		}
		
		cddb_set_server_name(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBServer"] UTF8String]);
		cddb_set_server_port(_freeDB, [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBPort"]);
		
		if(PROTO_HTTP == [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBProtocol"]) {
			cddb_http_enable(_freeDB);
		}
		else {
			cddb_http_disable(_freeDB);
		}
		
		cddb_set_email_address(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"emailAddress"] UTF8String]);

		// Proxy support
		if([[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBUseProxy"]) {
			cddb_http_proxy_enable(_freeDB);
			
			cddb_set_http_proxy_server_name(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBProxyServer"] UTF8String]);
			cddb_set_http_proxy_server_port(_freeDB, [[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBProxyPort"]);
			
			if([[NSUserDefaults standardUserDefaults] integerForKey:@"freeDBUseAuthentication"]) {
				cddb_set_http_proxy_username(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBProxyUsername"] UTF8String]);
				cddb_set_http_proxy_password(_freeDB, [[[NSUserDefaults standardUserDefaults] stringForKey:@"freeDBProxyPassword"] UTF8String]);				
			}			
		}
		
		// Client information
		bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		cddb_set_client(_freeDB, "Max", [bundleVersion UTF8String]);		
		
		cddb_cache_disable(_freeDB);
		
		return self;
	}
	return nil;
}

- (id) initWithCompactDiscDocument:(CompactDiscDocument *)disc;
{
	if((self = [self init])) {
		_disc = [disc retain];
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	cddb_destroy(_freeDB);
	[_disc release];
	[super dealloc];
}

- (NSArray *) fetchSites
{
	const cddb_site_t		*site			= NULL;
	NSMutableArray			*sites			= [NSMutableArray arrayWithCapacity:20];
	const char				*tempString;
	unsigned int			i;
	float					latitude, longitude;
	NSMutableDictionary		*currentSite;
	
	
	cddb_sites(_freeDB);
	// For some reason, cddb_sites ALWAYS returns 0 (in my testing anyway)
	if(FALSE == cddb_sites(_freeDB)) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"Unable to obtain list of FreeDB mirrors.\nlibcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}
	
	site = cddb_first_site(_freeDB);
	while(NULL != site) {
		currentSite = [NSMutableDictionary dictionaryWithCapacity:20];
		
		if(CDDB_ERR_OK == cddb_site_get_address(site, &tempString, &i)) {
			[currentSite setValue:[NSString stringWithUTF8String:tempString] forKey:@"address"];
			[currentSite setValue:[NSNumber numberWithUnsignedInt:i] forKey:@"port"];
		}
		
		[currentSite setValue:[NSNumber numberWithInt:cddb_site_get_protocol(site)] forKey:@"protocol"];
		
		if(CDDB_ERR_OK == cddb_site_get_description(site, &tempString)) {
			[currentSite setValue:[NSString stringWithUTF8String:tempString] forKey:@"siteDescription"];
		}
		
		if(CDDB_ERR_OK == cddb_site_get_location(site, &latitude, &longitude)) {
			[currentSite setValue:[NSNumber numberWithFloat:latitude] forKey:@"latitude"];
			[currentSite setValue:[NSNumber numberWithFloat:longitude] forKey:@"longitude"];
		}
		
		[sites addObject:currentSite];
		site = cddb_next_site(_freeDB);
	}
	
	return [[sites retain] autorelease];
}

- (NSArray *) fetchMatches
{
	NSMutableArray			*result			= [NSMutableArray arrayWithCapacity:10];
	cddb_disc_t				*freeDBDisc		= [[_disc getDisc] getFreeDBDisc];
	int						matches;
	NSMutableDictionary		*currentMatch;
	

	// Run query to find matches
	matches = cddb_query(_freeDB, freeDBDisc);
	if(-1 == matches) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"libcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}

	while(matches > 0) {
		currentMatch = [NSMutableDictionary dictionaryWithCapacity:6];
		
		[currentMatch setValue:[NSString stringWithUTF8String:cddb_disc_get_artist(freeDBDisc)] forKey:@"artist"];
		[currentMatch setValue:[NSString stringWithUTF8String:cddb_disc_get_title(freeDBDisc)] forKey:@"title"];
		[currentMatch setValue:[NSNumber numberWithUnsignedInt:cddb_disc_get_year(freeDBDisc)] forKey:@"year"];
		[currentMatch setValue:[NSString stringWithUTF8String:cddb_disc_get_genre(freeDBDisc)] forKey:@"genre"];
		[currentMatch setValue:[NSNumber numberWithInt:cddb_disc_get_category(freeDBDisc)] forKey:@"category"];
		[currentMatch setValue:[NSNumber numberWithUnsignedInt:cddb_disc_get_discid(freeDBDisc)] forKey:@"discid"];

		[result addObject:currentMatch];
		
		--matches;
		if(0 < matches) {
			if(0 == cddb_query_next(_freeDB, freeDBDisc)) {
				@throw [FreeDBException exceptionWithReason:@"Query index out of bounds" userInfo:nil];
			}
		}
	}
		
	return [[result retain] autorelease];
}

- (void) updateDisc:(NSDictionary *)info
{
	cddb_disc_t				*disc			= NULL;
	cddb_track_t			*track			= NULL;
	const char				*tempString;
	int						tempInt;
	
	// Create disc structure
	disc = cddb_disc_new();
	if(NULL == disc) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") userInfo:nil];
	}

	cddb_disc_set_category(disc, [[info valueForKey:@"category"] intValue]);
	cddb_disc_set_discid(disc, [[info valueForKey:@"discid"] unsignedIntValue]);
	
	if(0 == cddb_read(_freeDB, disc)) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"libcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}

	tempString = cddb_disc_get_title(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithUTF8String:tempString] forKey:@"title"];
	}
	
	tempString = cddb_disc_get_artist(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithUTF8String:tempString] forKey:@"artist"];		
	}
	
	tempString = cddb_disc_get_genre(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithUTF8String:tempString] forKey:@"genre"];		
	}
	
	tempInt = cddb_disc_get_year(disc);
	if(0 != tempInt) {
		[_disc setValue:[NSNumber numberWithUnsignedInt:tempInt] forKey:@"year"];
	}

	tempString = cddb_disc_get_ext_data(disc);
	if(NULL != tempString) {
		[_disc setValue:[NSString stringWithUTF8String:tempString] forKey:@"comment"];		
	}
	
	track = cddb_disc_get_track_first(disc);
	while(NULL != track) {
		
		tempString = cddb_track_get_title(track);
		if(NULL != tempString) {
			[[[_disc valueForKey:@"tracks"] objectAtIndex:cddb_track_get_number(track) - 1] setValue:[NSString stringWithUTF8String:tempString] forKey:@"title"];
		}

		tempString = cddb_track_get_artist(track);
		if(NULL != tempString && NO == [[NSString stringWithUTF8String:tempString] isEqualToString:[_disc valueForKey:@"artist"]]) {
			[_disc setValue:[NSNumber numberWithBool:YES] forKey:@"multiArtist"];
			[[[_disc valueForKey:@"tracks"] objectAtIndex:cddb_track_get_number(track) - 1] setValue:[NSString stringWithUTF8String:tempString] forKey:@"artist"];
		}
		
		track = cddb_disc_get_track_next(disc);
	}

	cddb_disc_destroy(disc);
}

- (void) submitDisc
{
	cddb_disc_t			*disc;
	id					temp;
	NSArray				*tracks;
	cddb_track_t		*track;
	Track				*currentTrack;
	unsigned			i;

	
	disc = cddb_disc_clone([[_disc getDisc] getFreeDBDisc]);
	if(NULL == disc) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") userInfo:nil];
	}

	temp = [_disc valueForKey:@"genre"];
	if(nil != temp) {
		cddb_disc_set_category_str(disc, [[temp lowercaseString] UTF8String]);
	}
	else {
		cddb_disc_set_category(disc, CDDB_CAT_MISC);
	}
	
	// Fill in the cddb_disc_t with data from the CompactDiscDocument
	temp = [_disc valueForKey:@"title"];
	if(nil != temp) {
		cddb_disc_set_title(disc, [temp UTF8String]);
	}

	temp = [_disc valueForKey:@"artist"];
	if(nil != temp) {
		cddb_disc_set_artist(disc, [temp UTF8String]);
	}

	temp = [_disc valueForKey:@"genre"];
	if(nil != temp) {
		cddb_disc_set_genre(disc, [temp UTF8String]);
	}

	temp = [_disc valueForKey:@"year"];
	if(nil != temp) {
		cddb_disc_set_year(disc, [temp unsignedIntValue]);
	}

	temp = [_disc valueForKey:@"comment"];
	if(nil != temp) {
		cddb_disc_set_ext_data(disc, [temp UTF8String]);
	}
			
	tracks = [_disc valueForKey:@"tracks"];
	for(i = 0; i < [tracks count]; ++i) {
		currentTrack	= [tracks objectAtIndex:i];
		track			= cddb_disc_get_track(disc, i);

		temp = [currentTrack valueForKey:@"title"];
		if(nil != temp) {
			cddb_track_set_title(track, [temp UTF8String]);
		}

		if([[_disc valueForKey:@"multiArtist"] boolValue]) {
			temp = [currentTrack valueForKey:@"artist"];
		}
		else {
			temp = [_disc valueForKey:@"artist"];
		}

		if(nil != temp) {
			cddb_track_set_artist(track, [temp UTF8String]);
		}
	}

	if(0 == cddb_write(_freeDB, disc)) {
		@throw [FreeDBException exceptionWithReason:[NSString stringWithFormat:@"libcddb reported: %s", cddb_error_str(cddb_errno(_freeDB))] userInfo:nil];
	}
	
	// Clean up
	cddb_disc_destroy(disc);
}

@end
