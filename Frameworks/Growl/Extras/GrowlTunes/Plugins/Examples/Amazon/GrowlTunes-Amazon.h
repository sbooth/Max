//
//  GrowlTunes-Amazon.h
//  GrowlTunes-Amazon
//
//  Created by Karl Adam on 9/29/04.
//  Copyright 2004 matrixPointer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GrowlTunesPlugin.h"

@interface GrowlTunes_Amazon: NSObject <GrowlTunesPlugin>
{
	BOOL	weGetInternet;
}


- (NSImage *)artworkForTitle:(NSString *)newSong
					byArtist:(NSString *)newArtist
					 onAlbum:(NSString *)newAlbum
			   isCompilation:(BOOL)newCompilation;

#pragma mark -
#pragma mark Amazon-searching methods

//Gets all albums by the specified artist. (Warning: May also return bodycare products.)
// But that's not what it asks amazon for, so just be careful with this badboy! ;-) //XXX - explain this?!
- (NSArray *)getAlbumsByArtist:(NSString *)artistName;

//Tries to find an album by a known albumName and artistName (can return many albums)
- (NSDictionary *)getAlbum:(NSString *)albumName byArtist:(NSString *)artistName;

/*Sends a query to Amazon web services.
 *Returns the raw XML data (may be nil, if e.g. server is unreachable).
 */
- (NSData *)queryAmazon:(NSString *)query; // "query" is actually just the GET args after the address.

#pragma mark -
#pragma mark Other

- (NSImage *)imageWithAlbumInfo:(NSDictionary *)albumInfo;

/*Downloads the contents of the specified URL.
 *If an error is encountered, it is logged, and this method returns nil.
 */
- (NSData *)download:(NSURL *)address;

@end
