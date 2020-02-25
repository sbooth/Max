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

void PerformMusicBrainzQuery(NSString *discID, void (^completionHandler)(NSArray*))
{
	/*
		 // Set MB server and port
		 NSString *server = @"musicbrainz.org";
		 if(nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"]) {
			 server = [[NSUserDefaults standardUserDefaults] stringForKey:@"musicBrainzServer"];
		 }

		 int port = 80;
		 if(nil != [[NSUserDefaults standardUserDefaults] objectForKey:@"musicBrainzServerPort"]) {
			 port = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"musicBrainzServerPort"];
		 }

	 //	NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
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
	 */
	NSString *url = [NSString stringWithFormat:@"https://musicbrainz.org/ws/2/discid/%@?inc=artists+labels+recordings+release-groups+artist-credits&fmt=json", discID];

	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	request.URL = [NSURL URLWithString:url];
	request.HTTPMethod = @"GET";

	NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	[request setValue:[NSString stringWithFormat:@"Max %@", bundleVersion] forHTTPHeaderField:@"User-Agent"];

	[request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

	NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];

	NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:[request autorelease] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if(nil == data) {
			return;
		}

		NSError *err = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
//		NSLog(@"%@",json);

		NSMutableArray *releaseArray = [NSMutableArray array];

		NSArray *releases = [json objectForKey:@"releases"];
		for(NSDictionary *release in releases) {
			NSMutableDictionary *releaseDictionary = [NSMutableDictionary dictionary];

			[releaseDictionary setValue:[release objectForKey:@"id"] forKey:@"id"];
			[releaseDictionary setValue:[release objectForKey:@"title"] forKey:@"title"];
			[releaseDictionary setValue:[release objectForKey:@"date"] forKey:@"date"];

			NSArray *artistCredit = [release objectForKey:@"artist-credit"];
			NSDictionary *artist = [[artistCredit firstObject] objectForKey:@"artist"];
			[releaseDictionary setValue:[artist objectForKey:@"name"] forKey:@"artist"];
			[releaseDictionary setValue:[artist objectForKey:@"id"] forKey:@"artistId"];

			NSMutableArray *tracksArray = [NSMutableArray array];

			NSArray *media = [release objectForKey:@"media"];
			for(NSDictionary *medium in media) {
				NSArray *tracks = [medium objectForKey:@"tracks"];
				for(NSDictionary *track in tracks) {
					NSMutableDictionary *trackDictionary = [NSMutableDictionary dictionary];

					[trackDictionary setValue:[track objectForKey:@"id"] forKey:@"trackId"];
					[trackDictionary setValue:[track objectForKey:@"number"] forKey:@"trackNumber"];
					[trackDictionary setValue:[track objectForKey:@"title"] forKey:@"title"];

					artistCredit = [track objectForKey:@"artist-credit"];
					artist = [[artistCredit firstObject] objectForKey:@"artist"];
					[trackDictionary setValue:[artist objectForKey:@"name"] forKey:@"artist"];
					[trackDictionary setValue:[artist objectForKey:@"id"] forKey:@"artistId"];

					[tracksArray addObject:trackDictionary];
				}
			}

			[releaseDictionary setValue:tracksArray forKey:@"tracks"];
			[releaseArray addObject:releaseDictionary];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(releaseArray);
		});
	}];

	[dataTask resume];
}
