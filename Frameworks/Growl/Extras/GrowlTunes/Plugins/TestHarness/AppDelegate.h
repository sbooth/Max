//
//  AppDelegate.h
//  TestHarness
//
//  Created by Kevin Ballard on 9/29/04.
//  Copyright 2004 TildeSoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject {
	NSArray *plugins;
	NSImage *currentImage;
	NSString *artist;
	NSString *album;
	NSString *song;
	NSNumber *compilation;
	IBOutlet NSWindow *mainWindow;

	/*IBOutlet NSTextField *artistField;
	IBOutlet NSTextField *albumField;
	IBOutlet NSTextField *songField;*/

	IBOutlet NSArrayController *pluginsController;
}
- (NSArray *) plugins;
- (void) setPlugins:(NSArray *)array;

- (NSImage *) currentImage;
- (void) setCurrentImage:(NSImage *)image;

- (NSString *)artist;
- (void)setArtist:(NSString *)anArtist;

- (NSString *)album;
- (void)setAlbum:(NSString *)anAlbum;

- (NSString *)song;
- (void)setSong:(NSString *)aSong;

- (NSNumber *)compilation;
- (void)setCompilation:(NSNumber *)isCompilation;

// actions
- (void) testPlugin;

- (IBAction) open:(id)sender;

@end

@protocol GrowlTunesPlugin
- (NSImage *)artworkForTitle:(NSString *)track
					byArtist:(NSString *)artist
					 onAlbum:(NSString *)album
			   isCompilation:(BOOL)compilation;
@end
