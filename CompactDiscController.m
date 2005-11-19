/*
 *  $Id$
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

#import "CompactDiscController.h"

#import "Track.h"
#import "CDDB.h"
#import "CDDBMatchSheet.h"
#import "Genres.h"
#import "TaskMaster.h"
#import "Encoder.h"
#import "Tagger.h"

#import "CDDBException.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "EmptySelectionException.h"
#import "MissingResourceException.h"

#import "UtilityFunctions.h"

#include <unistd.h>		// unlink

@implementation CompactDiscController

+ (void)initialize
{
	BOOL					isDir;
	NSFileManager			*manager;
	NSArray					*paths;
	NSString				*compactDiscControllerDefaultsValuesPath;
    NSDictionary			*compactDiscControllerDefaultsValuesDictionary;
	
	@try {
		// Set up defaults
		compactDiscControllerDefaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"CompactDiscControllerDefaults" ofType:@"plist"];
		if(nil == compactDiscControllerDefaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:@"Unable to load CompactDiscControllerDefaults.plist" userInfo:nil];
		}
		compactDiscControllerDefaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:compactDiscControllerDefaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:compactDiscControllerDefaultsValuesDictionary];
		
		// Create application data directory if needed
		manager		= [NSFileManager defaultManager];
		paths		= NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		gDataDir	= [[[paths objectAtIndex:0] stringByAppendingString:@"/Max"] retain];
		if(NO == [manager fileExistsAtPath:gDataDir isDirectory:&isDir]) {
			if(NO == [manager createDirectoryAtPath:gDataDir attributes:nil]) {
				@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
			}
		}
		else if(NO == isDir) {
			@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
		}
	}
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	@finally {
	}	
}

- (NSArray *)genres
{
	return [Genres sharedGenres];
}

- (id) init
{
	@throw [NSException exceptionWithName:@"InternalInconsistencyException" reason:@"CompactDiscController init called" userInfo:nil];
	return nil;
}

- (id) initWithDisc: (CompactDisc *) disc
{
	@try {
		if(self = [super initWithWindowNibName:@"CompactDisc"]) {
			
			_disc = [disc retain];

			_stop = [NSNumber numberWithBool:FALSE];
						
			// Load data from file if it exists
			NSFileManager	*manager	= [NSFileManager defaultManager];
			NSString		*discPath	= [NSString stringWithFormat:@"%@/0x%.8x.xml", gDataDir, [_disc cddb_id]];
			BOOL			fileExists	= [manager fileExistsAtPath:discPath isDirectory:nil];

			if(YES == fileExists) {
				NSData					*xmlData	= [manager contentsAtPath:discPath];
				NSDictionary			*discInfo;
				NSPropertyListFormat	format;
				NSString				*error;
				
				discInfo = [NSPropertyListSerialization propertyListFromData:xmlData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
				if(nil != discInfo) {
					[_disc setPropertiesFromDictionary:discInfo];
				}
				else {
					[error release];
				}
			}
			
			// Query CDDB if disc not previously seen
			if(YES == fileExists && nil != [disc valueForKey:@"title"]) {
				[[self window] setTitle:[disc valueForKey:@"title"]];
			}
			else {
				[[self window] setTitle:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];
			}
			[self setWindowFrameAutosaveName:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];	
			[self showWindow:self];

			[_disc addObserver:self forKeyPath:@"title" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
			
			// Query CDDB if disc not previously seen
			if(NO == fileExists) {
				[self getCDInformation:nil];
			}
		}
	}
	
	@catch(NSException *exception) {
		[self release];
		displayExceptionAlert(exception);
		@throw;
	}
	
	@finally {
		
	}
	
	return self;
}

- (void) dealloc
{
	[_disc release];
	[super dealloc];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqual:@"title"]) {
		if(YES == [[change objectForKey:NSKeyValueChangeNewKey] isEqual:[NSNull null]]) {
			[[self window] setTitle:[NSString stringWithFormat: @"Compact Disc 0x%.8x", [_disc cddb_id]]];
		}
		else {
			[[self window] setTitle:[change objectForKey:NSKeyValueChangeNewKey]];
		}
    }
}

- (void) discUnmounted
{
	[[self window] performClose:self];
}

- (IBAction)showTrackInfo:(id)sender
{
	[_trackDrawer toggle:self];
}

- (IBAction) selectAll:(id)sender
{
	int			i;
	NSArray		*tracks = [_disc valueForKey:@"tracks"];
	
	for(i = 0; i < [tracks count]; ++i) {
		[[tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:YES] forKey:@"selected"];
	}
}

- (IBAction) selectNone:(id)sender
{
	int			i;
	NSArray		*tracks = [_disc valueForKey:@"tracks"];
	
	for(i = 0; i < [tracks count]; ++i) {
		[[tracks objectAtIndex:i] setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
	}
}

- (IBAction)encode:(id)sender
{
	Track			*track;
	NSArray			*selectedTracks;
	NSEnumerator	*enumerator;
	NSString		*filename;
	NSString		*outputDirectory;
	
	@try {
		// Do nothing for empty selection
		if([self emptySelection]) {
			@throw [EmptySelectionException exceptionWithReason:@"Please select one or more tracks to encode." userInfo:nil];
		}

		// Iterate through the selected tracks and rip/encode them
		selectedTracks	= [_disc selectedTracks];
		enumerator		= [selectedTracks objectEnumerator];

		// Create output directory (should exist but could have been deleted/moved)
		outputDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.outputDirectory"] stringByExpandingTildeInPath];
		validateAndCreateDirectory(outputDirectory);
		
		while(track = [enumerator nextObject]) {

			// Use custom naming scheme
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.useCustomNaming"]) {
				
				NSMutableString		*customPath			= [[NSMutableString alloc] initWithCapacity:100];
				NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"org.sbooth.Max.customNamingScheme"];
				NSString			*path;
				
				// Get the elements needed to build the pathname
				NSNumber			*discNumber			= [_disc valueForKey:@"discNumber"];
				NSNumber			*discsInSet			= [_disc valueForKey:@"discsInSet"];
				NSString			*discArtist			= [_disc valueForKey:@"artist"];
				NSString			*discTitle			= [_disc valueForKey:@"title"];
				NSString			*discGenre			= [_disc valueForKey:@"genre"];
				NSNumber			*discYear			= [_disc valueForKey:@"year"];
				NSNumber			*trackNumber		= [track valueForKey:@"number"];
				NSString			*trackArtist		= [track valueForKey:@"artist"];
				NSString			*trackTitle			= [track valueForKey:@"title"];
				NSString			*trackGenre			= [track valueForKey:@"genre"];
				NSNumber			*trackYear			= [track valueForKey:@"year"];
				
				// Fallback to disc if specified in preferences
				if([[NSUserDefaults standardUserDefaults] boolForKey:@"org.sbooth.Max.customNamingUseFallback"]) {
					if(nil == trackArtist) {
						trackArtist = discArtist;
					}
					if(nil == trackGenre) {
						trackGenre = discGenre;
					}
					if(nil == trackYear) {
						trackYear = discYear;
					}
				}
				
				if(nil == customNamingScheme) {
					@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Invalid custom naming string." userInfo:nil];
				}
				else {
					[customPath setString:customNamingScheme];
				}
				
				if(nil == discNumber) {
					[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[discNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];					
				}
				if(nil == discsInSet) {
					[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:[discsInSet stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discArtist) {
					[customPath replaceOccurrencesOfString:@"{discArtist}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discArtist}" withString:makeStringSafeForFilename(discArtist) options:nil range:NSMakeRange(0, [customPath length])];					
				}
				if(nil == discTitle) {
					[customPath replaceOccurrencesOfString:@"{discTitle}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discTitle}" withString:makeStringSafeForFilename(discTitle) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discGenre) {
					[customPath replaceOccurrencesOfString:@"{discGenre}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discGenre}" withString:makeStringSafeForFilename(discGenre) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == discYear) {
					[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{discYear}" withString:[discYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackNumber) {
					[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[trackNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackArtist) {
					[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackTitle) {
					[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:makeStringSafeForFilename(trackTitle) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackGenre) {
					[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:makeStringSafeForFilename(trackGenre) options:nil range:NSMakeRange(0, [customPath length])];
				}
				if(nil == trackYear) {
					[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
				}
				else {
					[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[trackYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
				}

				// Create the directory structure
				NSArray *pathComponents = [customPath pathComponents];

				// pathComponents will always contain at least 1 element since customNamingScheme was not nil
				path = [NSString stringWithFormat:@"%@/%@", outputDirectory, makeStringSafeForFilename([pathComponents objectAtIndex:0])]; 

				if(1 < [pathComponents count]) {
					int				i;
					int				directoryCount		= [pathComponents count] - 1;
					
					validateAndCreateDirectory(path);
					for(i = 1; i < directoryCount; ++i) {						
						path = [NSString stringWithFormat:@"%@/%@", path, makeStringSafeForFilename([pathComponents objectAtIndex:i])];
						validateAndCreateDirectory(path);
					}
					
					filename = [NSString stringWithFormat:@"%@/%@", path, makeStringSafeForFilename([pathComponents objectAtIndex:i])];
				}
				else {
					filename = path;
				}
				[customPath release];
			}
			// Use standard iTunes-style naming for compilations: "Compilations/Album/DiscNumber-TrackNumber TrackTitle.mp3"
			else if(YES == [[_disc valueForKey:@"multiArtist"] boolValue]) {
				NSString			*path;
				
				NSString			*discTitle			= [_disc valueForKey:@"title"];
				NSString			*trackTitle			= [track valueForKey:@"title"];
				
				if(nil == discTitle) {
					discTitle = @"Unknown Album";
				}
				if(nil == trackTitle) {
					trackTitle = @"Unknown Track";
				}
				
				// Create the directory structure
				path = [NSString stringWithFormat:@"%@/Compilations", outputDirectory]; 
				validateAndCreateDirectory(path);

				path = [NSString stringWithFormat:@"%@/Compilations/%@", outputDirectory, makeStringSafeForFilename(discTitle)]; 
				validateAndCreateDirectory(path);
				
				if(nil == [_disc valueForKey:@"discNumber"]) {
					filename = [NSString stringWithFormat:@"%@/%02u %@.mp3", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
				else {
					filename = [NSString stringWithFormat:@"%@/%i-%02u %@.mp3", path, [[_disc valueForKey:@"discNumber"] intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
			}
			// Use standard iTunes-style naming: "Artist/Album/DiscNumber-TrackNumber TrackTitle.mp3"
			else {
				NSString			*path;
				
				NSString			*discArtist			= [_disc valueForKey:@"artist"];
				NSString			*trackArtist		= [track valueForKey:@"artist"];
				NSString			*artist;
				NSString			*discTitle			= [_disc valueForKey:@"title"];
				NSString			*trackTitle			= [track valueForKey:@"title"];
				
				artist = trackArtist;
				if(nil == artist) {
					artist = discArtist;
					if(nil == artist) {
						artist = @"Unknown Artist";
					}
				}
				if(nil == discTitle) {
					discTitle = @"Unknown Album";
				}
				if(nil == trackTitle) {
					trackTitle = @"Unknown Track";
				}
				
				// Create the directory structure
				path = [NSString stringWithFormat:@"%@/%@", outputDirectory, makeStringSafeForFilename(artist)]; 
				validateAndCreateDirectory(path);
				
				path = [NSString stringWithFormat:@"%@/%@/%@", outputDirectory, makeStringSafeForFilename(artist), makeStringSafeForFilename(discTitle)]; 
				validateAndCreateDirectory(path);
				
				if(nil == [_disc valueForKey:@"discNumber"]) {
					filename = [NSString stringWithFormat:@"%@/%02u %@.mp3", path, [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
				else {
					filename = [NSString stringWithFormat:@"%@/%i-%02u %@.mp3", path, [[_disc valueForKey:@"discNumber"] intValue], [[track valueForKey:@"number"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
				}
			}
			
			// Check if the output file exists
			if(YES == [[NSFileManager defaultManager] fileExistsAtPath:filename]) {
				NSAlert *alert = [[[NSAlert alloc] init] autorelease];
				[alert addButtonWithTitle:@"No"];
				[alert addButtonWithTitle:@"Yes"];
				[alert setMessageText:@"Overwrite existing file?"];
				[alert setInformativeText:[NSString stringWithFormat:@"The file '%@' already exists.  Do you wish to replace it?", filename]];
				[alert setAlertStyle:NSWarningAlertStyle];

				if(NSAlertSecondButtonReturn == [alert runModal]) {
					// Remove the file
					if(-1 == unlink([filename UTF8String])) {
						@throw [IOException exceptionWithReason:[NSString stringWithFormat:@"Unable to delete output file (%i:%s)", errno, strerror(errno)] userInfo:nil];
					}

					// Create and run the task
					Task *task = [[[Task alloc] initWithDisc:_disc forTrack:track outputFilename:filename] autorelease];
					[[TaskMaster sharedController] runTask:task];
				}
			}
			else {
				// Create and run the task
				Task *task = [[[Task alloc] initWithDisc:_disc forTrack:track outputFilename:filename] autorelease];
				[[TaskMaster sharedController] runTask:task];
			}
		}
	}

	@catch(NSException *exception) {
		[self displayExceptionSheet:exception];
	}

	@finally {
		
	}
}

- (IBAction)getCDInformation:(id)sender
{
	CDDB				*cddb				= nil;
	NSArray				*matches			= nil;
	CDDBMatchSheet		*sheet				= nil;

	@try {
		cddb = [[[CDDB alloc] init] autorelease];
		[cddb setValue:_disc forKey:@"disc"];
		
		matches = [cddb fetchMatches];
		
		if(0 == [matches count]) {
			@throw [CDDBException exceptionWithReason:@"No matches found for this disc." userInfo:nil];
		}
		else if(1 == [matches count]) {
			[self updateDiscFromCDDB:[matches objectAtIndex:0]];
		}
		else {
			sheet = [[[CDDBMatchSheet alloc] init] autorelease];
			[sheet setValue:matches forKey:@"matches"];
			[sheet setValue:self forKey:@"controller"];
			[sheet showCDDBMatches];
		}
	}
	
	@catch(NSException *exception) {
		[self displayExceptionSheet:exception];
	}
	
	@finally {
	}
}

- (void) updateDiscFromCDDB:(CDDBMatch *)info
{
	CDDB *cddb;
	
	@try {
		cddb = [[CDDB alloc] init];
		[cddb setValue:_disc forKey:@"disc"];
		
		[cddb updateDisc:info];
	}

	@catch(NSException *exception) {
		[self displayExceptionSheet:exception];
	}
	
	@finally {
		[cddb release];		
	}
	
}

- (BOOL) emptySelection
{
	return (0 == [[_disc selectedTracks] count]);
}

- (void) displayExceptionSheet:(NSException *)exception
{
	displayExceptionSheet(exception, [self window], self, @selector(alertDidEnd:returnCode:contextInfo:), nil);
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Nothing for now
}

#pragma mark NSDrawer delegate methods

- (void)drawerDidClose:(NSNotification *)notification
{
	if([notification object] == _trackDrawer) {
		[_trackInfoButton setTitle:@"Show Track Info"];
	}
}

- (void)drawerDidOpen:(NSNotification *)notification
{
	if([notification object] == _trackDrawer) {
		[_trackInfoButton setTitle:@"Hide Track Info"];
	}
}

#pragma mark NSWindow delegate methods

- (void) windowWillClose:(NSNotification *) aNotification
{
	// Save data from file if it exists
	NSFileManager			*manager	= [NSFileManager defaultManager];
	NSString				*discPath	= [NSString stringWithFormat:@"%@/0x%.8x.xml", gDataDir, [_disc cddb_id]];
	NSData					*xmlData;
	NSString				*error;
	
	if(! [manager fileExistsAtPath:discPath isDirectory:nil]) {
		[manager createFileAtPath:discPath contents:nil attributes:nil];
	}
	
	xmlData = [NSPropertyListSerialization dataFromPropertyList:[_disc getDictionary] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	if(nil != xmlData) {
		[xmlData writeToFile:discPath atomically:YES];
	}
	else {
		[error release];
	}
}

@end
