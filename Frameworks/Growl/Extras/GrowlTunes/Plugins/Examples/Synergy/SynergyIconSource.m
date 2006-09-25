//
//  SynergyIconSource.m
//  GrowlTunes-Synergy
//
//  Created by Mac-arena the Bored Zo on 08/31/2004.
//  Public domain.
//	based on a patch submitted by J. Nicholas Jitkoff to the Growl project.
//

#import "SynergyIconSource.h"

static NSString *empty = @"";

@implementation SynergyIconSource

//to load the plug-in, GrowlTunes does [[[plugin principalClass] alloc] init].
//so any initialisation is to be done in -init.

- init {
	self = [super init];
	//create this middle section all at once in advance.
	if (!synergySubPath)
		synergySubPath = [[[@"Application Support" stringByAppendingPathComponent:@"Synergy"] stringByAppendingPathComponent:@"Album Covers"] retain];
	return self;
}

//to unload the plug-in, GrowlTunes releases it.*
//so any clean-up is to be done in -dealloc.
// *actually, it releases the array in which it keeps the plug-ins, and the
//  array releases it.

- (void) dealloc {
	[synergySubPath release];

	[super dealloc];
}

//a debugging pleasantry. GrowlTunes doesn't actually use this ATM.

- (NSString *) description {
	return [NSString stringWithFormat:@"<GrowlTunes-Synergy instance at %p>", self];
}

//this is where things happen. when GrowlTunes is about to notify, but can't get
//  artwork from iTunes, it calls - artworkForTitle:byArtist:onAlbum: on your
//  plug-in.

- (NSImage *) artworkForTitle:(NSString *)song byArtist:(NSString *)artist onAlbum:(NSString *)album isCompilation:(BOOL)compilation {
#pragma unused(compilation)
	NSMutableString *synergyFile;

	/*construct the filename that Synergy would use to save album art.*/
	{
		//albums are preferred over songs.
		if ([album length])
			synergyFile = [NSMutableString stringWithFormat:@"Artist-%@,Album-%@.tiff", artist, album];
		else
			synergyFile = [NSMutableString stringWithFormat:@"Artist-%@,Song-%@.tiff",  artist, song];

		//weed out characters that are unsafe for HFS+ and the file-system in general.
		NSRange span = { 0U, [synergyFile length] };
		span.length -= [synergyFile replaceOccurrencesOfString:@" " withString:empty options:0U range:span];
		span.length -= [synergyFile replaceOccurrencesOfString:@"/" withString:empty options:0U range:span];
					   [synergyFile replaceOccurrencesOfString:@":" withString:empty options:0U range:span];
	}

	NSFileManager *mgr = [NSFileManager defaultManager];

	/*look through the available Synergy caches for a file with the filename we constructed earlier.*/
	{
		//exclude the system domain, since we'll never find a Synergy cache there.
		enum { allButSystemMask = NSAllDomainsMask & ~NSSystemDomainMask };
		NSEnumerator *libraryEnum = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, allButSystemMask, /*expandTilde*/ YES) objectEnumerator];
		NSString *thisSubPath = [synergySubPath stringByAppendingPathComponent:synergyFile];
		NSString *thisFullPath;

		//we return an image created from the first matching file we find - if we do find one.
		//note: thisFullPath = [libraryEnum nextObject] + synergySubPath + synergyFile.
		while ((thisFullPath = [[libraryEnum nextObject] stringByAppendingPathComponent:thisSubPath]))
			if ([mgr fileExistsAtPath:thisFullPath])
				return [[[NSImage alloc] initWithContentsOfFile:thisFullPath] autorelease];
	}

	//we got nothin'.
	return nil;
}

- (BOOL) usesNetwork {
	return NO;
}

@end
