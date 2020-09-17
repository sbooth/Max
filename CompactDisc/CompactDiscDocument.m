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

#import "CompactDiscDocument.h"

#import "CompactDiscDocumentToolbar.h"
#import "CompactDiscController.h"
#import "Track.h"
#import "AudioMetadata.h"
#import "Genres.h"
#import "RipperController.h"
#import "PreferencesController.h"
#import "FormatsController.h"
#import "Encoder.h"
#import "MediaController.h"

#import "MusicBrainzHelper.h"
#import "MusicBrainzMatchSheet.h"

#import "UtilityFunctions.h"

@interface CompactDiscDocument (Private)
- (void) displayExceptionAlert:(NSAlert *)alert;
- (void) updateMetadataFromMusicBrainz:(NSDictionary *)releaseDictionary;
@end

@implementation CompactDiscDocument

+ (BOOL) accessInstanceVariablesDirectly	{ return NO; }

- (id) init
{
	if((self = [super init])) {		
		_tracks = [[NSMutableArray alloc] init];		
	}
	return self;
}

- (void) dealloc
{	
	[_disc release];					_disc = nil;

	[_discID release];					_discID = nil;

	[_title release];					_title = nil;
	[_artist release];					_artist = nil;
	[_date release];					_date = nil;
	[_genre release];					_genre = nil;
	[_composer release];				_composer = nil;
	[_comment release];					_comment = nil;

	[_albumArt release];				_albumArt = nil;

	[_discNumber release];				_discNumber = nil;
	[_discTotal release];				_discTotal = nil;
	[_compilation release];				_compilation = nil;

	[_musicbrainzAlbumId release];		_musicbrainzAlbumId = nil;
	[_musicbrainzArtistId release];		_musicbrainzArtistId = nil;
	
	[_MCN release];						_MCN = nil;
	
	[_tracks release];					_tracks = nil;
	
	[super dealloc];
}

- (void) awakeFromNib
{
	// Set number formatters	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[_discNumberTextField setFormatter:numberFormatter];
	[_discTotalTextField setFormatter:numberFormatter];
	[numberFormatter release];

	[_trackTable setAutosaveName:[NSString stringWithFormat: @"Tracks for %@", [self discID]]];
	[_trackTable setAutosaveTableColumns:YES];
	[_trackController setSortDescriptors:[NSArray arrayWithObjects:
		[[[NSSortDescriptor alloc] initWithKey:@"number" ascending:YES] autorelease],
		nil]];	
}

#pragma mark NSDocument overrides

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
	if([item action] == @selector(encode:)) {
		[item setTitle:NSLocalizedStringFromTable(@"Encode Selected Tracks", @"Menus", @"")];
		return [self encodeAllowed];
	}
	else if([item action] == @selector(queryMusicBrainz:))
		return [self queryMusicBrainzAllowed];
	else if([item action] == @selector(ejectDisc:))
		return [self ejectDiscAllowed];
	else if([item action] == @selector(submitDiscId:))
		return [self submitDiscIdAllowed];
	else if([item action] == @selector(selectNextTrack:))
		return [_trackController canSelectNext];
	else if([item action] == @selector(selectPreviousTrack:))
		return [_trackController canSelectPrevious];
	else if([item action] == @selector(toggleMetadataInspectorPanel:)) {
		if([_metadataPanel isVisible])
			[item setTitle:NSLocalizedStringFromTable(@"Hide Track Inspector", @"Menus", @"")];
		else
			[item setTitle:NSLocalizedStringFromTable(@"Show Track Inspector", @"Menus", @"")];

		return YES;
	}
	else
		return [super validateMenuItem:item];
}

- (void) makeWindowControllers 
{
	CompactDiscController *controller = [[CompactDiscController alloc] initWithWindowNibName:@"CompactDiscDocument" owner:self];
	[self addObserver:controller forKeyPath:@"title" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
	[self addWindowController:[controller autorelease]];
}

- (void) windowControllerDidLoadNib:(NSWindowController *)controller
{
	[controller setShouldCascadeWindows:NO];
	[controller setWindowFrameAutosaveName:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Compact Disc %@", @"CompactDisc", @""), [self discID]]];
	
	CompactDiscDocumentToolbar *toolbar = [[CompactDiscDocumentToolbar alloc] initWithCompactDiscDocument:self];
    
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    
    [toolbar setDelegate:toolbar];
	
    [[controller window] setToolbar:[toolbar autorelease]];
}

- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if([typeName isEqualToString:@"Max CD Information"]) {
		NSData					*data					= nil;
		NSString				*error					= nil;
		NSMutableDictionary		*result					= [NSMutableDictionary dictionaryWithCapacity:10];
		NSMutableArray			*tracks					= [NSMutableArray arrayWithCapacity:[self countOfTracks]];
		NSUInteger				i;
		
		[result setValue:[self title] forKey:@"title"];
		[result setValue:[self artist] forKey:@"artist"];
		[result setValue:[self date] forKey:@"date"];
		[result setValue:[self genre] forKey:@"genre"];
		[result setValue:[self composer] forKey:@"composer"];
		[result setValue:[self comment] forKey:@"comment"];
		[result setValue:[self discNumber] forKey:@"discNumber"];
		[result setValue:[self discTotal] forKey:@"discTotal"];
		[result setValue:[self compilation] forKey:@"compilation"];
		[result setValue:[self musicbrainzAlbumId] forKey:@"musicbrainzAlbumId"];
		[result setValue:[self musicbrainzArtistId] forKey:@"musicbrainzArtistId"];
		[result setValue:[self MCN] forKey:@"MCN"];
		[result setValue:[self discID] forKey:@"discID"];
		
		if(nil != [self albumArt]) {
			data = GetPNGDataForImage([self albumArt]); 
			[result setValue:data forKey:@"albumArt"];
		}
		
		for(i = 0; i < [self countOfTracks]; ++i)
			[tracks addObject:[[self objectInTracksAtIndex:i] getDictionary]];
		
		[result setValue:tracks forKey:@"tracks"];

		data = [NSPropertyListSerialization dataFromPropertyList:result format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
		if(nil != data)
			return data;
		else
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:[NSDictionary dictionaryWithObject:[error autorelease] forKey:NSLocalizedFailureReasonErrorKey]];
	}
	return nil;
}

- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{    
	if([typeName isEqualToString:@"Max CD Information"]) {
		NSDictionary			*dictionary;
		NSPropertyListFormat	format;
		NSString				*error;
		
		dictionary = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error];
		if(nil != dictionary) {
			NSUInteger				i;
			NSArray					*tracks			= [dictionary valueForKey:@"tracks"];
			
			if([self discInDrive] && [tracks count] != [self countOfTracks]) {
				@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track count mismatch between the disc and the saved document." userInfo:nil];
			}
			else if(0 == [self countOfTracks]) {
				for(i = 0; i < [tracks count]; ++i) {
					Track *track = [[[Track alloc] init] autorelease];
					[track setDocument:self];
					[track setPropertiesFromDictionary:[tracks objectAtIndex:i]];
					[self insertObject:track inTracksAtIndex:i];
				}
			}
			
			[_title release];						_title = nil;
			[_artist release];						_artist = nil;
			[_date release];						_date = nil;
			[_genre release];						_genre = nil;
			[_composer release];					_composer = nil;
			[_comment release];						_comment = nil;
			
			[_albumArt release];					_albumArt = nil;

			[_musicbrainzAlbumId release];			_musicbrainzAlbumId = nil;
			[_musicbrainzArtistId release];			_musicbrainzArtistId = nil;
			
			[_discNumber release];					_discNumber = nil;
			[_discTotal release];					_discTotal = nil;
			
			[_discID release];						_discID = nil;
			[_MCN release];							_MCN = nil;
			
			_discID			= [[dictionary valueForKey:@"discID"] retain];

			_title			= [[dictionary valueForKey:@"title"] retain];
			_artist			= [[dictionary valueForKey:@"artist"] retain];
			_date			= [[dictionary valueForKey:@"date"] retain];
			_genre			= [[dictionary valueForKey:@"genre"] retain];
			_composer		= [[dictionary valueForKey:@"composer"] retain];
			_comment		= [[dictionary valueForKey:@"comment"] retain];

			_musicbrainzAlbumId = [[dictionary valueForKey:@"musicbrainzAlbumId"] retain];
			_musicbrainzArtistId = [[dictionary valueForKey:@"musicbrainzArtistId"] retain];

			_discNumber		= [[dictionary valueForKey:@"discNumber"] retain];
			_discTotal		= [[dictionary valueForKey:@"discTotal"] retain];
			_compilation	= [[dictionary valueForKey:@"compilation"] retain];	

			_MCN			= [[dictionary valueForKey:@"MCN"] retain];

			// Maintain backwards compatibility
			if(nil == _date && nil != [dictionary valueForKey:@"year"] && 0 != [[dictionary valueForKey:@"year"] intValue])
				_date		= [[[dictionary valueForKey:@"year"] stringValue] retain];

			// Convert PNG data to an NSImage
			_albumArt				= [[NSImage alloc] initWithData:[dictionary valueForKey:@"albumArt"]];
		}
		else
			[error release];

		return YES;
	}
    return NO;
}

#pragma mark Delegate methods

- (void) windowWillClose:(NSNotification *)notification
{
	NSArray *controllers = [self windowControllers];
	if(0 != [controllers count]) {
		[self removeObserver:[controllers objectAtIndex:0] forKeyPath:@"title"];
	}
}

- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)sender
{
	return [self undoManager];
}

#pragma mark Disc Management

- (BOOL)			ejectRequested							{ return _ejectRequested; }
- (void)			setEjectRequested:(BOOL)ejectRequested	{ _ejectRequested = ejectRequested; }

- (void) discEjected				{ [self setDisc:nil]; }

#pragma mark State

- (BOOL) encodeAllowed				{ return ([self discInDrive] && NO == [self emptySelection] && NO == [self ripInProgress] && NO == [self encodeInProgress]); }
- (BOOL) queryMusicBrainzAllowed	{ return YES; }
- (BOOL) ejectDiscAllowed			{ return [self discInDrive]; }
- (BOOL) submitDiscIdAllowed		{ return [self discInDrive]; }
- (BOOL) emptySelection				{ return (0 == [[self selectedTracks] count]); }

- (BOOL) ripInProgress
{
	NSUInteger i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		if([[self objectInTracksAtIndex:i] ripInProgress]) {
			return YES;
		}
	}
	
	return NO;
}

- (BOOL) encodeInProgress
{
	NSUInteger i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		if([[self objectInTracksAtIndex:i] encodeInProgress]) {
			return YES;
		}
	}
	
	return NO;
}

#pragma mark Action Methods

- (IBAction) selectAll:(id)sender
{
	NSUInteger i;
	
	for(i = 0; i < [self countOfTracks]; ++i)
		[[self objectInTracksAtIndex:i] setSelected:YES];
}

- (IBAction) selectNone:(id)sender
{
	NSUInteger i;
	
	for(i = 0; i < [self countOfTracks]; ++i)
		[[self objectInTracksAtIndex:i] setSelected:NO];
}

- (IBAction) encode:(id)sender
{
	@try {
		NSMutableDictionary		*postProcessingOptions	= nil;
		NSArray					*applicationPaths		= nil;

		// Do nothing if the disc isn't in the drive, the selection is empty, or a rip/encode is in progress
		if(NO == [self discInDrive]) {
			NSBeep();
			return;
		}
		
		NSAssert(NO == [self emptySelection], NSLocalizedStringFromTable(@"No tracks are selected for encoding.", @"Exceptions", @""));
		NSAssert(NO == [self ripInProgress] && NO == [self encodeInProgress], NSLocalizedStringFromTable(@"A ripping or encoding operation is already in progress.", @"Exceptions", @""));		
		
		// Encoders
		NSArray *encoders = [[FormatsController sharedController] selectedFormats];

		// Verify at least one output format is selected
		if(0 == [encoders count]) {
			NSInteger		result;
			
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
			[alert addButtonWithTitle: NSLocalizedStringFromTable(@"Show Preferences", @"General", @"")];
			[alert setMessageText:NSLocalizedStringFromTable(@"No output formats are selected.", @"General", @"")];
			[alert setInformativeText:NSLocalizedStringFromTable(@"Please select one or more output formats.", @"General", @"")];
			[alert setAlertStyle: NSWarningAlertStyle];
			
			result = [alert runModal];
			
			if(NSAlertFirstButtonReturn == result) {
				// do nothing
			}
			else if(NSAlertSecondButtonReturn == result) {
				[[PreferencesController sharedPreferences] selectPreferencePane:FormatsPreferencesToolbarItemIdentifier];
				[[PreferencesController sharedPreferences] showWindow:self];
			}
			
			return;
		}

		NSMutableDictionary *settings = [NSMutableDictionary dictionary];
		[settings setValue:encoders forKey:@"encoders"];
		
		// Ripper settings
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"selectedRipper"] forKey:@"selectedRipper"];
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"ripToSingleFile"] forKey:@"ripToSingleFile"];
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"generateCueSheet"] forKey:@"generateCueSheet"];
		
		// File locations
		[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath] forKey:@"outputDirectory"];
//		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"convertInPlace"] forKey:@"convertInPlace"];
		[settings setValue:[[[NSUserDefaults standardUserDefaults] stringForKey:@"temporaryDirectory"] stringByExpandingTildeInPath] forKey:@"temporaryDirectory"];
		
		// Conversion parameters
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"saveSettingsInComment"] forKey:@"saveSettingsInComment"];
		//		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"deleteSourceFiles"] forKey:@"deleteSourceFiles"];
		[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"overwriteOutputFiles"] forKey:@"overwriteOutputFiles"];
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"overwriteOutputFiles"]) {
			[settings setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"promptBeforeOverwritingOutputFiles"] forKey:@"promptBeforeOverwritingOutputFiles"];
		}
		
		// Output file naming
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomOutputFileNaming"]) {
			NSMutableDictionary		*fileNamingFormat = [NSMutableDictionary dictionary];
			
			[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"fileNamingFormat"] forKey:@"formatString"];
			[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"useTwoDigitTrackNumbers"] forKey:@"useTwoDigitTrackNumbers"];
			[fileNamingFormat setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"useNamingFallback"] forKey:@"useNamingFallback"];
			
			[settings setValue:fileNamingFormat forKey:@"outputFileNaming"];
		}
		
		// Post-processing options
		postProcessingOptions = [NSMutableDictionary dictionary];
		
		[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"addToiTunes"] forKey:@"addToiTunes"];
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"addToiTunes"]) {
			
			[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"addToiTunesPlaylist"] forKey:@"addToiTunesPlaylist"];
			
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"addToiTunesPlaylist"]) {
				[postProcessingOptions setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"iTunesPlaylistName"] forKey:@"iTunesPlaylistName"];
			}		
		}
		
		applicationPaths	= [[NSUserDefaults standardUserDefaults] objectForKey:@"postProcessingApplications"];
		
		if(0 != [applicationPaths count]) {
			[postProcessingOptions setValue:applicationPaths forKey:@"postProcessingApplications"];
		}
		
		if(0 != [postProcessingOptions count]) {
			[settings setValue:postProcessingOptions forKey:@"postProcessingOptions"];
		}
		
		// Album art
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"saveAlbumArt"]) {
			NSMutableDictionary		*albumArt = [NSMutableDictionary dictionary];
			
			[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileExtension"] forKey:@"extension"];
			[albumArt setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"albumArtFileNamingFormat"] forKey:@"formatString"];
			
			[settings setValue:albumArt forKey:@"albumArt"];
		}
		
		// Rip the tracks
		[[RipperController sharedController] ripTracks:[self selectedTracks] settings:settings];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while ripping tracks from the disc \"%@\".", @"Exceptions", @""), (nil == [self title] ? [self discID] : [self title])]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[self displayExceptionAlert:alert];
	}
}

- (IBAction) ejectDisc:(id) sender
{
	if(NO == [self discInDrive]) {
		return;
	}
	
	if([self ripInProgress]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Do you want to eject the disc \"%@\" while ripping is in progress?", @"CompactDisc", @""), (nil == [self title] ? [self discID] : [self title])]];
		[alert setInformativeText:NSLocalizedStringFromTable(@"Your incomplete rips will be lost.", @"CompactDisc", @"")];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if(NSAlertSecondButtonReturn == [alert runModal]) {
			return;
		}
		// Stop all associated rip tasks
		else {
			[[RipperController sharedController] stopRipperTasksForDocument:self];
		}

		// Until the RipperTasks have actually stopped, there could be open file
		// descriptors on the disc and the eject will fail
		// So just set a flag here, and the last task to stop will eject the disc
		[self setEjectRequested:YES];
	}
	else {
		[[MediaController sharedController] ejectDiscForDocument:self];
	}
}

- (IBAction) submitDiscId:(id)sender;
{
	[[NSWorkspace sharedWorkspace] openURL:[[self disc] discIDSubmissionUrl]];
}

- (IBAction) queryMusicBrainz:(id)sender
{
	if(![self queryMusicBrainzAllowed]) {
		return;
	}

	PerformMusicBrainzQuery([self discID], ^(NSArray *results, NSError *error) {
		if(nil == results) {
			if(nil != error) {
				NSAlert *alert = [NSAlert alertWithError:error];
				[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
				}];
			}
		}
		else if(0 == [results count]) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No matches.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No releases matching this disc were found in MusicBrainz.", @"CompactDisc", @"")];
			[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
			}];
		}
		// If only match was found, update ourselves
		else if(1 == [results count]) {
			NSDictionary *release = [results firstObject];
			[self updateMetadataFromMusicBrainz:release];
			[self downloadAlbumArt:sender];
		}
		else {
			MusicBrainzMatchSheet	*sheet		= [[MusicBrainzMatchSheet alloc] init];
			[sheet setValue:results forKey:@"matches"];
			[[self windowForSheet] beginSheet:[sheet sheet] completionHandler:^(NSModalResponse returnCode) {
				if(NSOKButton == returnCode) {
					NSDictionary *release = [sheet selectedRelease];
					[self updateMetadataFromMusicBrainz:release];
					[self downloadAlbumArt:sender];
				}
			}];
			[sheet release];
		}
	});
}

- (void) queryMusicBrainzNonInteractive
{
	if(![self queryMusicBrainzAllowed]) {
		return;
	}
	
	PerformMusicBrainzQuery([self discID], ^(NSArray *results, NSError *error) {
		if(0 < [results count]) {
			NSDictionary *release = [results firstObject];
			[self updateMetadataFromMusicBrainz:release];
			NSString *releaseID = [release objectForKey:@"albumId"];
			PerformCoverArtArchiveQuery(releaseID, ^(NSImage *image, NSError *error) {
				if(nil != image) {
					[self setAlbumArt:image];
				}
			});
		}
	});
}

- (IBAction) toggleMetadataInspectorPanel:(id)sender
{
	if(![_metadataPanel isVisible]) {
		[_metadataPanel orderFront:sender];
	}
	else {
		[_metadataPanel orderOut:sender];
	}
}

- (IBAction) selectNextTrack:(id)sender						{ [_trackController selectNext:sender]; }
- (IBAction) selectPreviousTrack:(id)sender					{ [_trackController selectPrevious:sender];	 }

- (IBAction) downloadAlbumArt:(id)sender
{
	if(![self queryMusicBrainzAllowed]) {
		return;
	}

	if(nil == _musicbrainzAlbumId) {
		PerformMusicBrainzQuery([self discID], ^(NSArray *results, NSError *error) {
			if(nil == results) {
				if(nil != error) {
					NSAlert *alert = [NSAlert alertWithError:error];
					[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
					}];
				}
			}
			else if(0 == [results count]) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No matches.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No releases matching this disc were found in MusicBrainz.", @"CompactDisc", @"")];
				[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
				}];
			}
			else {
				NSDictionary *release = [results firstObject];
				NSString *releaseID = [release objectForKey:@"albumId"];
				PerformCoverArtArchiveQuery(releaseID, ^(NSImage *image, NSError *error) {
					if(nil != error) {
						NSAlert *alert = [NSAlert alertWithError:error];
						[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
						}];
					}
					else if(nil == image) {
						NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No album art.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No front cover art matching this disc was found.", @"CompactDisc", @"")];
						[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
						}];
					}
					else {
						[self setAlbumArt:image];
					}
				});
			}
		});
	}
	else {
		PerformCoverArtArchiveQuery(_musicbrainzAlbumId, ^(NSImage *image, NSError *error) {
			if(nil != error) {
				NSAlert *alert = [NSAlert alertWithError:error];
				[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
				}];
			}
			else if(nil == image) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"No album art.", @"CompactDisc", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedStringFromTable(@"No front cover art matching this disc was found.", @"CompactDisc", @"")];
				[alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode) {
				}];
			}
			else {
				[self setAlbumArt:image];
			}
		});
	}
}

- (IBAction) selectAlbumArt:(id) sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowedFileTypes:[NSImage imageFileTypes]];
	
	[panel beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse result) {
	    if(NSOKButton == result) {
			for(NSURL *url in [panel URLs]) {
				NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
				if(nil != image) {
					[self setAlbumArt:[image autorelease]];
				}
			}
		}
	}];
}

#pragma mark Miscellaneous

- (NSString *)		length								{ return [NSString stringWithFormat:@"%lu:%.2lu", [[self disc] length] / 60, [[self disc] length] % 60]; }
- (NSArray *)		genres								{ return [Genres sharedGenres]; }

- (NSArray *) selectedTracks
{
	NSUInteger		i;
	NSMutableArray	*result			= [NSMutableArray arrayWithCapacity:[self countOfTracks]];
	Track			*track;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		track = [self objectInTracksAtIndex:i];
		if([track selected]) {
			[result addObject:track];
		}
	}

	return [[result retain] autorelease];
}

#pragma mark Accessors

- (CompactDisc *)	disc								{ return [[_disc retain] autorelease]; }
- (BOOL)			discInDrive							{ return _discInDrive; }
- (NSString *)		discID								{ return ([self discInDrive] ? [[self disc] discID] : _discID); }

- (NSString *)		title								{ return [[_title retain] autorelease]; }
- (NSString *)		artist								{ return [[_artist retain] autorelease]; }
- (NSString *)		date								{ return [[_date retain] autorelease]; }
- (NSString *)		genre								{ return [[_genre retain] autorelease]; }
- (NSString *)		composer							{ return [[_composer retain] autorelease]; }
- (NSString *)		comment								{ return [[_comment retain] autorelease]; }

- (NSImage *)		albumArt							{ return [[_albumArt retain] autorelease]; }

- (NSNumber *)		discNumber							{ return [[_discNumber retain] autorelease]; }
- (NSNumber *)		discTotal							{ return [[_discTotal retain] autorelease]; }
- (NSNumber *)		compilation							{ return [[_compilation retain] autorelease]; }

- (NSString *)		musicbrainzArtistId					{ return [[_musicbrainzArtistId retain] autorelease]; }
- (NSString *)		musicbrainzAlbumId					{ return [[_musicbrainzAlbumId retain] autorelease]; }

- (NSString *)		MCN									{ return [[_MCN retain] autorelease]; }

- (NSUInteger)		countOfTracks						{ return [_tracks count]; }
- (Track *)			objectInTracksAtIndex:(NSUInteger)idx { return [_tracks objectAtIndex:idx]; }

#pragma mark Mutators

- (void) setDisc:(CompactDisc *)disc
{
	NSUInteger			i;

	if(NO == [[self disc] isEqual:disc]) {

		[_disc release];
		_disc = [disc retain];
		
		if(nil == disc) {
			[self setDiscInDrive:NO];
			return;
		}
		
		[self setDiscInDrive:YES];

		[self setDiscID:[_disc discID]];
		[self setMCN:[_disc MCN]];
		
		if(0 == [self countOfTracks]) {
			for(i = 0; i < [[self disc] countOfTracks]; ++i) {
				Track *track = [[Track alloc] init];
				[track setDocument:self];
				[_tracks addObject:[track autorelease]];
			}
		}
		
		for(i = 0; i < [[self disc] countOfTracks]; ++i) {
			Track			*track		= [_tracks objectAtIndex:i];
			
			[track setNumber:i + 1];
			[track setFirstSector:[_disc firstSectorForTrack:i]];
			[track setLastSector:[_disc lastSectorForTrack:i]];
			
			[track setChannels:[_disc channelsForTrack:i]];
			[track setPreEmphasis:[_disc trackHasPreEmphasis:i]];
			[track setCopyPermitted:[_disc trackAllowsDigitalCopy:i]];
			[track setISRC:[_disc ISRCForTrack:i]];
		}
	}
}

- (void) setDiscInDrive:(BOOL)discInDrive						{ _discInDrive = discInDrive; }
- (void) setDiscID:(NSString *)discID							{ [_discID release]; _discID = [discID retain]; }

- (void) setTitle:(NSString *)title
{
	if(NO == [[self title] isEqualToString:title]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setTitle:) object:_title];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Title", @"UndoRedo", @"")];
		[_title release];
		_title = [title retain];
	}
}

- (void) setArtist:(NSString *)artist
{
	if(NO == [[self artist] isEqualToString:artist]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setArtist:) object:_artist];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Artist", @"UndoRedo", @"")];
		[_artist release];
		_artist = [artist retain];
	}
}

- (void) setDate:(NSString *)date
{
	if(_date != date) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDate:) object:_date];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Date", @"UndoRedo", @"")];
		[_date release];
		_date = [date retain];
	}
}

- (void) setGenre:(NSString *)genre
{
	if(NO == [[self genre] isEqualToString:genre]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setGenre:) object:_genre];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Genre", @"UndoRedo", @"")];
		[_genre release];
		_genre = [genre retain];
	}
}

- (void) setComposer:(NSString *)composer
{
	if(NO == [[self composer] isEqualToString:composer]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComposer:) object:_composer];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Composer", @"UndoRedo", @"")];
		[_composer release];
		_composer = [composer retain];
	}
}

- (void) setComment:(NSString *)comment
{
	if(NO == [[self comment] isEqualToString:comment]) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setComment:) object:_comment];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Comment", @"UndoRedo", @"")];
		[_comment release];
		_comment = [comment retain];
	}
}

- (void) setAlbumArt:(NSImage *)albumArt
{
	if(NO == [[self albumArt] isEqual:albumArt]) {
		[[self undoManager] beginUndoGrouping];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setAlbumArt:) object:_albumArt];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Album Art", @"UndoRedo", @"")];
		[[self undoManager] endUndoGrouping];
		[_albumArt release];
		_albumArt = [albumArt retain];
	}
}

- (void) setDiscNumber:(NSNumber *)discNumber
{
	if(_discNumber != discNumber) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDiscNumber:) object:_discNumber];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Disc Number", @"UndoRedo", @"")];
		[_discNumber release];
		_discNumber = [discNumber retain];
	}
}

- (void) setDiscTotal:(NSNumber *)discTotal
{
	if(_discTotal != discTotal) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setDiscTotal:) object:_discTotal];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Total Discs", @"UndoRedo", @"")];
		[_discTotal release];
		_discTotal = [discTotal retain];
	}
}

- (void) setCompilation:(NSNumber *)compilation
{
	if(_compilation != compilation) {
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setCompilation:) object:_compilation];
		[[self undoManager] setActionName:NSLocalizedStringFromTable(@"Compilation", @"UndoRedo", @"")];
		[_compilation release];
		_compilation = [compilation retain];
	}
}

- (void) setMCN:(NSString *)MCN { [_MCN release]; _MCN = [MCN retain]; }

- (void) setMusicbrainzArtistId:(NSString *)musicbrainzArtistId
		 { [_musicbrainzArtistId release]; _musicbrainzArtistId = [musicbrainzArtistId retain]; }
- (void) setMusicbrainzAlbumId:(NSString *)musicbrainzAlbumId
		 { [_musicbrainzAlbumId release]; _musicbrainzAlbumId = [musicbrainzAlbumId retain]; }

- (void) insertObject:(Track *)track inTracksAtIndex:(NSUInteger)idx		{ [_tracks insertObject:track atIndex:idx]; }
- (void) removeObjectFromTracksAtIndex:(NSUInteger)idx					{ [_tracks removeObjectAtIndex:idx]; }

@end

@implementation CompactDiscDocument (ScriptingAdditions)

- (id) handleEncodeScriptCommand:(NSScriptCommand *)command					{ [self encode:command]; return nil; }
- (id) handleEjectDiscScriptCommand:(NSScriptCommand *)command				{ [self ejectDisc:command]; return nil; }
- (id) handleQueryMusicBrainzScriptCommand:(NSScriptCommand *)command		{ [self queryMusicBrainz:command]; return nil; }
- (id) handleToggleInspectorPanelScriptCommand:(NSScriptCommand *)command 	{ [self toggleMetadataInspectorPanel:command]; return nil; }

@end

@implementation CompactDiscDocument (Private)

- (void) displayExceptionAlert:(NSAlert *)alert
{
	NSWindow *window = [self windowForSheet];
	if(nil == window) {
		[alert runModal];
	}
	else {
		[alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	}
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Nothing for now
}

- (void) updateMetadataFromMusicBrainz:(NSDictionary *)releaseDictionary
{
	[[self undoManager] beginUndoGrouping];

	[self setTitle:[releaseDictionary valueForKey:@"title"]];
	[self setArtist:[releaseDictionary valueForKey:@"artist"]];
	[self setComposer:[releaseDictionary valueForKey:@"composer"]];
	[self setDate:[releaseDictionary valueForKey:@"date"]];
	[self setDiscNumber:[releaseDictionary valueForKey:@"position"]];
	[self setMusicbrainzAlbumId:[releaseDictionary valueForKey:@"albumId"]];
	[self setMusicbrainzArtistId:[releaseDictionary valueForKey:@"artistId"]];

	NSArray *tracksArray = [releaseDictionary valueForKey:@"tracks"];

	NSUInteger i;
	for(i = 0; i < [tracksArray count]; ++i) {
		NSDictionary *trackDictionary = [tracksArray objectAtIndex:i];
		Track *track = [self objectInTracksAtIndex:i];

		[track setTitle:[trackDictionary valueForKey:@"title"]];
		[track setArtist:[trackDictionary valueForKey:@"artist"]];
		[track setComposer:[trackDictionary valueForKey:@"composer"]];
		[track setMusicbrainzTrackId:[trackDictionary valueForKey:@"trackId"]];
		if ([trackDictionary valueForKey:@"artistId"] != nil)
			[track setMusicbrainzArtistId:[trackDictionary valueForKey:@"artistId"]];
		else
			[track setMusicbrainzArtistId:[releaseDictionary valueForKey:@"artistId"]];
	}

	[self updateChangeCount:NSChangeReadOtherContents];

	[[self undoManager] setActionName:NSLocalizedStringFromTable(@"MusicBrainz", @"UndoRedo", @"")];
	[[self undoManager] endUndoGrouping];

}

@end
