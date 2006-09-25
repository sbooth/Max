//
//  ARTchiveIconSource.m
//  ARTchive
//
//  Created by Kevin Ballard on 9/29/04.
//  Copyright 2004 Kevin Ballard. All rights reserved.
//

#import "ARTchiveIconSource.h"
#import "ARTchiveStringAdditions.h"

@implementation ARTchiveIconSource

- (id) init {
	if ((self = [super init])) {
		NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
		NSDictionary *dict   = [defs persistentDomainForName:@"public.music.artwork"];

		libraryLocation      = [dict objectForKey:@"LibraryLocation"];
		if (!libraryLocation)  libraryLocation = @"~/Library/Images/Music";
		libraryLocation      = [[libraryLocation stringByExpandingTildeInPath] retain];

		preferredImage       = [[dict objectForKey:@"PreferredImage"]          retain];
		if (!preferredImage)   preferredImage  = @"Cover";

		artworkSubdirectory  = [[dict objectForKey:@"ArtworkSubdirectory"]     retain];
	}
	return self;
}

- (void)dealloc {
	[libraryLocation release];
	[preferredImage release];
	[artworkSubdirectory release];

	[super dealloc];
}

- (NSImage *)artworkForTitle:(NSString *)track byArtist:(NSString *)artist onAlbum:(NSString *)album isCompilation:(BOOL)compilation {
	NSString *artworkDir = [self pathForTrack:track artist:artist album:album compilation:compilation];

	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL isDir;
	if ([manager fileExistsAtPath:artworkDir isDirectory:&isDir] && isDir) {
		NSArray *extensions = [NSArray arrayWithObjects:@"tiff", @"tif", @"png", @"jpeg", @"jpg", @"gif", @"bmp", nil];
		if ([album length]) {
			// Check for PreferredImage.img
			NSString *path = [artworkDir stringByAppendingPathComponent:preferredImage];
			NSEnumerator *e = [extensions objectEnumerator];
			NSString *ext;
			while ((ext = [e nextObject])) {
				NSString *fullPath = [path stringByAppendingPathExtension:ext];
				if ([manager fileExistsAtPath:fullPath]) {
					return [[[NSImage alloc] initByReferencingFile:fullPath] autorelease];
				}
			}
			// Check for any other available image
			NSArray *matchingPaths = [[manager directoryContentsAtPath:artworkDir] pathsMatchingExtensions:extensions];
			if ([matchingPaths count]) {
				NSString *filename = [matchingPaths objectAtIndex:0];
				NSString *fullPath = [artworkDir stringByAppendingPathComponent:filename];
				return [[[NSImage alloc] initByReferencingFile:fullPath] autorelease];
			}
		}
		// Check for track-specific images
		if ([track length]) {
			track = [track stringByMakingPathSafe];
			// Check for Track.img, Album.img, Artist.img
			artworkDir = [artworkDir stringByAppendingPathComponent:@"Tracks"];
			artworkDir = [artworkDir stringByAppendingPathComponent:track];
			NSEnumerator *nameEnum = [[NSArray arrayWithObjects:@"Track", @"Album", @"Artist", nil] objectEnumerator];
			NSString *name;
			while ((name = [nameEnum nextObject])) {
				NSString *path = [artworkDir stringByAppendingPathComponent:name];
				NSEnumerator *e = [extensions objectEnumerator];
				NSString *ext;
				while ((ext = [e nextObject])) {
					NSString *fullPath = [path stringByAppendingPathExtension:ext];
					if ([manager fileExistsAtPath:fullPath]) {
						return [[[NSImage alloc] initByReferencingFile:fullPath] autorelease];
					}
				}
			}
			// Check for any other available image
			NSArray *matchingPaths = [[manager directoryContentsAtPath:artworkDir] pathsMatchingExtensions:extensions];
			if ([matchingPaths count]) {
				return [[[NSImage alloc] initByReferencingFile:[matchingPaths objectAtIndex:0]] autorelease];
			}
		}
	}
	return nil;
}

- (NSString *)pathForTrack:(NSString *)track artist:(NSString *)artist album:(NSString *)album compilation:(BOOL)compilation {
	// Protect string from itself
	if ([track length])
		track = [track stringByMakingPathSafe];

	if ([artist length])
		artist = [artist stringByMakingPathSafe];

	if ([album length])
		album = [album stringByMakingPathSafe];

	NSString *path = libraryLocation;

	if (compilation) {
		path = [path stringByAppendingPathComponent:@"Compilations"];
	} else {
		if ([artist length]) {
			path = [path stringByAppendingPathComponent:artist];
		} else {
			path = [path stringByAppendingPathComponent:@"Unknown Artist"];
		}
	}

	if ([album length]) {
		path = [path stringByAppendingPathComponent:album];
	} else {
		path = [path stringByAppendingPathComponent:@"Unknown Album"];
	}

	if (artworkSubdirectory)
		path = [path stringByAppendingPathComponent:artworkSubdirectory];

	return path;
}

- (BOOL) usesNetwork {
	return NO;
}

- (BOOL) createDirectoriesAtPath:(NSString *)inPath attributes:(NSDictionary *)inAttributes {
	NSArray       *components    = [inPath pathComponents];
	unsigned       numComponents = [components count];
	BOOL           result        = YES;
	NSFileManager *manager       = [NSFileManager defaultManager];
	NSWorkspace   *workspace     = [NSWorkspace sharedWorkspace];
	NSString      *lastSubpath   = nil;

	for (unsigned i = 1U; i <= numComponents; ++i) {
		NSArray *subComponents = [components subarrayWithRange:NSMakeRange(0,i)];
		NSString *subpath = [NSString pathWithComponents:subComponents];
		BOOL isDir;
		BOOL exists = [manager fileExistsAtPath:subpath isDirectory:&isDir];

		if (!exists) {
			result = [manager createDirectoryAtPath:subpath attributes:inAttributes];
			if (!result)
				return result;
			else
				[workspace noteFileSystemChanged:lastSubpath];
		}
		lastSubpath = subpath;
	}
	return result;
}


- (BOOL) archiveImage:(NSImage *)image track:(NSString *)track artist:(NSString *)artist album:(NSString *)album compilation:(BOOL)compilation {
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *artworkDir = [self pathForTrack:track artist:artist album:album compilation:compilation];

	NSString *fullPath = nil;
	if ([album length]) {
		NSString *component = [preferredImage stringByAppendingPathExtension:@"png"];
		fullPath = [artworkDir stringByAppendingPathComponent:component];
	} else {
		NSArray *components = [NSArray arrayWithObjects:artworkDir, @"Tracks", track, @"Track.png", nil];
		fullPath = [NSString pathWithComponents:components];
	}
	//NSLog(@"Archiving artwork at %@", fullPath);

	BOOL success = NO;
	if ([manager fileExistsAtPath:fullPath])
		NSLog(@"This is strange. %@ exists, but the ARTchive plug-in did not return artwork for it.", fullPath);
	else {
		NSData *imageData = [NSBitmapImageRep representationOfImageRepsInArray:[image representations] usingType:NSPNGFileType properties:nil];
		NSString *directory = [fullPath stringByDeletingLastPathComponent];
		success = [self createDirectoriesAtPath:directory attributes:nil];
		if (success) {
			success = [manager createFileAtPath:fullPath
			                           contents:imageData
			                         attributes:nil];
			if (success)
				[[NSWorkspace sharedWorkspace] noteFileSystemChanged:directory];
		}
	}
	return success;
}

@end
