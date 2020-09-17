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

void PerformMusicBrainzQuery(NSString *discID, void (^completionHandler)(NSArray *, NSError *))
{
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
			dispatch_async(dispatch_get_main_queue(), ^{
				completionHandler(nil, error);
			});
			return;
		}

		NSError *err = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];

		NSMutableArray *releaseArray = [NSMutableArray array];

		NSArray *releases = [json objectForKey:@"releases"];
		for(NSDictionary *release in releases) {
			NSMutableDictionary *releaseDictionary = [NSMutableDictionary dictionary];

			[releaseDictionary setValue:[release objectForKey:@"id"] forKey:@"albumId"];
			[releaseDictionary setValue:[release objectForKey:@"title"] forKey:@"title"];
			[releaseDictionary setValue:[release objectForKey:@"date"] forKey:@"date"];

			NSArray *artistCredit = [release objectForKey:@"artist-credit"];
			NSDictionary *artist = [[artistCredit firstObject] objectForKey:@"artist"];
			[releaseDictionary setValue:[artist objectForKey:@"name"] forKey:@"artist"];
			[releaseDictionary setValue:[artist objectForKey:@"id"] forKey:@"artistId"];

			NSMutableArray *tracksArray = [NSMutableArray array];

			NSArray *media = [release objectForKey:@"media"];
			for(NSDictionary *medium in media) {
				// Multi-disc releases contain information on all discs in the release, so
				// filter out media that don't have matching disc IDs
				BOOL mediumHasMatchingDiscID = NO;
				NSArray *discs = [medium objectForKey:@"discs"];
				for(NSDictionary *disc in discs) {
					if([discID isEqualToString:[disc objectForKey:@"id"]]) {
						mediumHasMatchingDiscID = YES;
						break;
					}
				}

				if(!mediumHasMatchingDiscID)
					continue;

				[releaseDictionary setValue:[medium objectForKey:@"position"] forKey:@"position"];

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

//			NSDictionary *coverArtArchive = [release objectForKey:@"cover-art-archive"];

			[releaseArray addObject:releaseDictionary];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(releaseArray, nil);
		});
	}];

	[dataTask resume];
}

void PerformCoverArtArchiveQuery(NSString *releaseID, void (^completionHandler)(NSImage *, NSError *))
{
	NSString *url = [NSString stringWithFormat:@"https://coverartarchive.org/release/%@", releaseID];

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
			dispatch_async(dispatch_get_main_queue(), ^{
				completionHandler(nil, error);
			});
			return;
		}

		NSError *err = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];

		NSURL *imageURL = nil;

		NSArray *images = [json objectForKey:@"images"];
		for(NSDictionary *image in images) {
			if([[image objectForKey:@"front"] boolValue]) {
				// Swap out http for https
				NSURLComponents *urlComponents = [NSURLComponents componentsWithString:[image objectForKey:@"image"]];
				urlComponents.scheme = @"https";
				imageURL = urlComponents.URL;
				break;
			}
		}

		NSImage *image = nil;
		if(nil != imageURL) {
			image = [[NSImage alloc] initWithContentsOfURL:imageURL];
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler(image, nil);
		});
	}];

	[dataTask resume];
}
