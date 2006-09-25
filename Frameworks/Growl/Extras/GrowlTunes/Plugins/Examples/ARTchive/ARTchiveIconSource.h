//
//  ARTchiveIconSource.h
//  ARTchive
//
//  Created by Kevin Ballard on 9/29/04.
//  Copyright 2004 Kevin Ballard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GrowlTunesPlugin.h"

@interface ARTchiveIconSource : NSObject <GrowlTunesPlugin, GrowlTunesPluginArchive> {
	NSString *libraryLocation;
	NSString *preferredImage;
	NSString *artworkSubdirectory;
}
- (NSString *)pathForTrack:(NSString *)track artist:(NSString *)artist album:(NSString *)album compilation:(BOOL)compilation;
@end
