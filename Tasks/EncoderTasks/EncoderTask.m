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

#import "EncoderTask.h"

#import "EncoderMethods.h"
#import "EncoderController.h"
#import "LogController.h"
#import "Track.h"

#import "UtilityFunctions.h"

@interface EncoderTask (Private)
- (void)			writeTags;

- (void)			touchOutputFile;

- (NSString *)		generateStandardBasenameUsingMetadata:(AudioMetadata *)metadata;
- (NSString *)		generateCustomBasenameUsingMetadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings substitutions:(NSDictionary *)substitutions;
@end

enum {
	kTIFFFileFormatMenuItemTag			= 0,
	kBMPFileFormatMenuItemTag			= 1,
	kGIFFileFormatMenuItemTag			= 2,
	kJPEGFileFormatMenuItemTag			= 3,
	kPNGFileFormatMenuItemTag			= 4,
	kJPEG200FileFormatMenuItemTag		= 5
};

@implementation EncoderTask

- (void) dealloc
{
	// Process tracks
	if(nil != [[self taskInfo] inputTracks]) {
		NSEnumerator	*enumerator		= nil;
		Track			*track			= nil;
		BOOL			shouldDelete	= YES;
		
		enumerator	= [[[self taskInfo] inputTracks] objectEnumerator];
	
		while((track = [enumerator nextObject])) {
			if(NO == [track ripInProgress] && NO == [track encodeInProgress]) {
				[track setSelected:NO];
			}
			else {
				shouldDelete = NO;
			}
		}

		if(shouldDelete) {
			NSArray		*inputFilenames		= [[self taskInfo] inputFilenames];
			unsigned	i;
			NSString	*inputFilename;
			
			for(i = 0; i < [inputFilenames count]; ++i) {
				inputFilename = [inputFilenames objectAtIndex:i];
				if([[NSFileManager defaultManager] fileExistsAtPath:inputFilename]) {
					BOOL			result			= [[NSFileManager defaultManager] removeItemAtPath:inputFilename error:nil];
					NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") );
				}
			}
		}
	}
	
	[_connection release];				_connection = nil;
	[_encoderSettings release];			_encoderSettings = nil;
	[_encoderSettingsString release];	_encoderSettingsString = nil;

	[super dealloc];
}

- (NSString *)		description
{
	NSString *result = [[[self taskInfo] metadata] description];
	if(nil == result)
		result = [[[[self taskInfo] inputFilenameAtInputFileIndex] lastPathComponent] stringByDeletingPathExtension];
	
	return result;
}

- (NSString *)		outputFormatName					{ return nil; }
- (NSString *)		fileExtension						{ return nil; }

- (NSDictionary *)	encoderSettings						{ return [[_encoderSettings retain] autorelease]; }
- (void)			setEncoderSettings:(NSDictionary *)encoderSettings 	{ [_encoderSettings release]; _encoderSettings = [encoderSettings retain]; }

- (NSString *)		encoderSettingsString				{ return _encoderSettingsString; }

- (void)			encoderReady:(id)anObject
{
	_encoder = [(NSObject<EncoderMethods>*) anObject retain];
    [anObject setProtocolForProxy:@protocol(EncoderMethods)];
	[anObject encodeToFile:[self outputFilename]];
}

- (void)			run
{
	NSString				*basename;
	NSPort					*port1				= [NSPort port];
	NSPort					*port2				= [NSPort port];
	NSArray					*portArray			= nil;
	
	// Encode in place?
	if(nil == [[self taskInfo] inputTracks] && [[[[self taskInfo] settings] objectForKey:@"convertInPlace"] boolValue])
		basename = [[[self taskInfo] inputFilenameAtInputFileIndex] stringByDeletingPathExtension];
	// Use the input filename if we're not encoding in place and no metadata was found
	else if(nil == [[self taskInfo] inputTracks] && [[[self taskInfo] metadata] isEmpty]) {
		basename = [NSString stringWithFormat:@"%@/%@",
			[[[[self taskInfo] settings] objectForKey:@"outputDirectory"] stringByExpandingTildeInPath],
			[[[[self taskInfo] inputFilenameAtInputFileIndex] lastPathComponent] stringByDeletingPathExtension] ];

		// Create the directory hierarchy if required
		CreateDirectoryStructure(basename);
	}
	// Use the standard file naming format
	else if(nil == [[[self taskInfo] settings] objectForKey:@"outputFileNaming"]) {
		basename = [NSString stringWithFormat:@"%@/%@",
			[[[[self taskInfo] settings] objectForKey:@"outputDirectory"] stringByExpandingTildeInPath],
			[self generateStandardBasenameUsingMetadata:[[self taskInfo] metadata]] ];

		// Create the directory hierarchy if required
		CreateDirectoryStructure(basename);
	}
	// Use a custom file naming format
	else {
		NSDictionary			*outputFileNaming	= [[[self taskInfo] settings] objectForKey:@"outputFileNaming"];
		NSMutableDictionary		*substitutions		= [NSMutableDictionary dictionary];
		
		// Set up the additional key/value pairs to be substituted
		[substitutions setObject:[self outputFormatName] forKey:@"fileFormat"];
		basename = [NSString stringWithFormat:@"%@/%@",
			[[[[self taskInfo] settings] objectForKey:@"outputDirectory"] stringByExpandingTildeInPath],
			[self generateCustomBasenameUsingMetadata:[[self taskInfo] metadata] settings:outputFileNaming substitutions:substitutions] ];

		// Create the directory hierarchy if required
		CreateDirectoryStructure(basename);
	}
	
	// Check if output file exists and delete if requested as long as the output and input files are not the same
	if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@.%@", basename, [self fileExtension]]] 
	   && [[[[self taskInfo] settings] objectForKey:@"overwriteOutputFiles"] boolValue]
	   && NO == [[NSString stringWithFormat:@"%@.%@", basename, [self fileExtension]] isEqualToString:[[self taskInfo] inputFilenameAtInputFileIndex]]) {
		BOOL			alertResult;
		NSString		*filename		= [NSString stringWithFormat:@"%@.%@", basename, [self fileExtension]];
		
		// Prompt whether to overwrite
		if([[[[self taskInfo] settings] objectForKey:@"promptBeforeOverwritingOutputFiles"] boolValue]) {
			NSAlert		*alert		= [[[NSAlert alloc] init] autorelease];
			
			[alert addButtonWithTitle:NSLocalizedStringFromTable(@"No", @"General", @"")];
			[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Yes", @"General", @"")];
			[alert addButtonWithTitle:NSLocalizedStringFromTable(@"Cancel", @"General", @"")];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"The file \"%@\" exists.", @"General", @""), [[NSFileManager defaultManager] displayNameAtPath:filename]]];
			[alert setInformativeText:NSLocalizedStringFromTable(@"Do you want to replace the existing file?", @"General", @"")];
			[alert setAlertStyle:NSInformationalAlertStyle];
			
			NSInteger			result		= [alert runModal];
			switch(result) {
				case NSAlertFirstButtonReturn:
					;
					break;
					
				case NSAlertSecondButtonReturn:				
					alertResult		= [[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
					NSAssert(YES == alertResult, NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") );
					break;

				case NSAlertThirdButtonReturn:
					[[EncoderController sharedController] encoderTaskDidStop:self notify:NO];
					return; //break;
			}		
		}
		// Otherwise just delete it
		else {
			alertResult = [[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
			NSAssert(YES == alertResult, NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") );
		}
	}

	// Otherwise, generate a unique filename and touch the output file
	[self setOutputFilename:GenerateUniqueFilename(basename, [self fileExtension])];
	[self touchOutputFile];
	
	// Save album art if desired
	if(nil != [[[self taskInfo] settings] objectForKey:@"albumArt"] && nil != [[[self taskInfo] metadata] albumArt]) {
		NSBitmapImageFileType	fileType;
		NSString				*extension;		
		
		NSDictionary *albumArtSettings	= [[[self taskInfo] settings] objectForKey:@"albumArt"];
		
		switch([[albumArtSettings objectForKey:@"extension"] intValue]) {
			case kTIFFFileFormatMenuItemTag:		fileType = NSTIFFFileType;			extension = @"tiff";		break;
			case kBMPFileFormatMenuItemTag:			fileType = NSBMPFileType;			extension = @"bmp";			break;
			case kGIFFileFormatMenuItemTag:			fileType = NSGIFFileType;			extension = @"gif";			break;
			case kJPEGFileFormatMenuItemTag:		fileType = NSJPEGFileType;			extension = @"jpeg";		break;
			case kPNGFileFormatMenuItemTag:			fileType = NSPNGFileType;			extension = @"png";			break;
			case kJPEG200FileFormatMenuItemTag:		fileType = NSJPEG2000FileType;		extension = @"jpeg";		break;
		}
		
		NSString *namingScheme = [albumArtSettings objectForKey:@"formatString"];
		if(nil == namingScheme)
			namingScheme = @"cover";
		
		NSData		*bitmapData			= GetBitmapDataForImage([[[self taskInfo] metadata] albumArt], fileType);
		NSString	*bitmapBasename		= [[[self outputFilename] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[[self taskInfo] metadata] replaceKeywordsInString:MakeStringSafeForFilename(namingScheme)]];
		//bitmapFilename		= generateUniqueFilename(bitmapBasename, extension);
		NSString	*bitmapFilename		= [bitmapBasename stringByAppendingPathExtension:extension];
		
		// Don't overwrite existing files
		if(NO == [[NSFileManager defaultManager] fileExistsAtPath:bitmapFilename]) {
			[bitmapData writeToFile:bitmapFilename atomically:NO];		
		}
	}
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];

	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted:YES];
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_encoderClass withObject:portArray];
}

- (void) setTaskInfo:(TaskInfo *)taskInfo
{
	[super setTaskInfo:taskInfo];

	// Mark tracks as started here so we know when the temporary files can be deleted
	if(nil != [[self taskInfo] inputTracks]) {
		NSArray			*tracks		= [[self taskInfo] inputTracks];
		unsigned		i;
		
		for(i = 0; i < [tracks count]; ++i) {
			[[tracks objectAtIndex:i] encodeStarted];
		}
	}	
}

- (void) setStarted:(BOOL)started
{
	[super setStarted:YES];

	// Mark tracks as started
/*	if(nil != [[self taskInfo] inputTracks]) {
		NSArray			*tracks		= [[self taskInfo] inputTracks];
		unsigned		i;
		
		for(i = 0; i < [tracks count]; ++i) {
			[[tracks objectAtIndex:i] encodeStarted];
		}
	}*/

	[[EncoderController sharedController] encoderTaskDidStart:self]; 
}

- (void) setStopped:(BOOL)stopped
{
	[super setStopped:YES]; 

	// Once we're stopped, clean up the encoder and invalidate the connection
	[(NSObject *)_encoder release];
	_encoder = nil;
	[_connection invalidate];

	// Mark tracks as complete
	if(nil != [[self taskInfo] inputTracks]) {
		NSArray			*tracks		= [[self taskInfo] inputTracks];
		unsigned		i;
		
		for(i = 0; i < [tracks count]; ++i) {
			[[tracks objectAtIndex:i] encodeCompleted];
		}
	}
	
	[self setShouldDeleteOutputFile:YES];
	
	[[EncoderController sharedController] encoderTaskDidStop:self]; 
}

- (void) setCompleted:(BOOL)completed
{
	// A task that never started or prematurely stopped can never complete
	if(NO == [self started] || [self stopped]) {
		return;
	}

	// Before severing the connection to the encoder, grab the settings string for tagging purposes
	_encoderSettingsString		= [[_encoder settingsString] retain];
	
	// Once we're complete, clean up the encoder and invalidate the connection
	[(NSObject *)_encoder release];
	_encoder = nil;
	[_connection invalidate];
	
/*
	// This file is finished
	[[self taskInfo] setInputFileIndex:[[self taskInfo] inputFileIndex] + 1];
	
	// Process any remaining files
	if([[self taskInfo] inputFileIndex] < [[[self taskInfo] inputFilenames] count]) {
		
	}
 */
	
	@try {

		// Tag file, if we have metadata
		if(nil != [[self taskInfo] metadata] && NO == [[[self taskInfo] metadata] isEmpty]) {
			[self writeTags];
		}
		
		// Run post-processing tasks
		if(nil != [[[self taskInfo] settings] objectForKey:@"postProcessingOptions"]) {
			NSDictionary		*postProcessingOptions;
			NSArray				*applications;
			unsigned			i;

			postProcessingOptions	= [[[self taskInfo] settings] objectForKey:@"postProcessingOptions"];
			applications			= [postProcessingOptions objectForKey:@"postProcessingApplications"];

			for(i = 0; i < [applications count]; ++i) {
				[[NSWorkspace sharedWorkspace] openFile:[self outputFilename] withApplication:[applications objectAtIndex:i] andDeactivate:NO];
			}
			
			if([[postProcessingOptions objectForKey:@"addToiTunes"] boolValue]) {
				AudioMetadata	*metadata		= [[self taskInfo] metadata];
				NSString		*playlist		= [postProcessingOptions objectForKey:@"iTunesPlaylistName"];

				// Set up the iTunes playlist
				if([[postProcessingOptions objectForKey:@"addToiTunesPlaylist"] boolValue] && nil != playlist) {
					// Flesh out specifiers
					playlist = [metadata replaceKeywordsInString:playlist];
					
					// Set the playlist in the metadata
					[metadata setPlaylist:playlist];
				}

				// Add to iTunes
				if([self formatIsValidForiTunes]) {
					AddFileToiTunesLibrary([self outputFilename], metadata);
				}				
			}
		}
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while tagging the file \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:[self outputFilename]]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
	
	@try {
		[super setCompleted:YES];
		
		// Delete input file if requested
		if(nil == [[self taskInfo] inputTracks] && [[[[self taskInfo] settings] objectForKey:@"deleteSourceFiles"] boolValue]) {
			NSArray			*filenames		= [[self taskInfo] inputFilenames];
			BOOL			result;

			for(NSString *filename in filenames) {
				result = [[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
				NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to delete the input file.", @"Exceptions", @""));
			}
		}

		// Generate cue sheet
		if(nil != [[self taskInfo] inputTracks] && [[[[self taskInfo] settings] objectForKey:@"generateCueSheet"] boolValue]) {
			if([self formatIsValidForCueSheet]) {
				[self generateCueSheet];
			}
			/*else {
				@throw [FileFormatNotSupportedException exceptionWithReason:NSLocalizedStringFromTable(@"Cue sheets are not supported for this output format.", @"Exceptions", @"")
																   userInfo:[NSDictionary dictionaryWithObject:[self outputFormat] forKey:@"fileFormat"]];
			}*/
		}

		// Mark tracks as complete
		if(nil != [[self taskInfo] inputTracks]) {
			NSArray			*tracks		= [[self taskInfo] inputTracks];
			unsigned		i;
			
			for(i = 0; i < [tracks count]; ++i) {
				[[tracks objectAtIndex:i] encodeCompleted];
			}
		}
			
		[[EncoderController sharedController] encoderTaskDidComplete:self];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while encoding the file \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:[self outputFilename]]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (void) stop
{
	if([self started] && NO == [self stopped]) {
		[self setShouldStop:YES];
	}
	else {
		[self setStopped:YES];
	}
}

- (void) setException:(NSException *)exception
{
	NSAlert		*alert		= nil;
	
	[super setException:exception];
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while encoding the file \"%@\".", @"Exceptions", @""), [[NSFileManager defaultManager] displayNameAtPath:[self outputFilename]]]];
	[alert setInformativeText:[[self exception] reason]];
	[alert setAlertStyle:NSWarningAlertStyle];		
	[alert runModal];
}

@end

@implementation EncoderTask (CueSheetAdditions)

- (BOOL)			formatIsValidForCueSheet			{ return NO; }
- (NSString *)		cueSheetFormatName					{ return nil; }

- (void) generateCueSheet
{
	NSString		*cueSheetFilename		= nil;
	NSString		*temp					= nil;
	NSString		*bundleVersion			= nil;
	Track			*currentTrack			= nil;
	const char		*buf					= NULL;
	int				fd						= -1;
	ssize_t			bytesWritten			= -1;
	unsigned		i;
	unsigned		m						= 0;
	unsigned		s						= 0;
	unsigned		f						= 0;
	
	if(nil == [[self taskInfo] inputTracks]) {
		return;
	}
	
	@try {
		cueSheetFilename = GenerateUniqueFilename([[self outputFilename] stringByDeletingPathExtension], @"cue");

		// Create the file (don't overwrite)
		fd = open([cueSheetFilename fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		NSAssert(-1 != fd, NSLocalizedStringFromTable(@"Unable to create the cue sheet.", @"Exceptions", @""));
		
		// REM
		bundleVersion	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		temp			= [NSString stringWithFormat:@"REM File created by Max %@\n", bundleVersion];
		buf				= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));
		
		// TITLE
		temp	= [NSString stringWithFormat:@"TITLE \"%@\"\n", [[[[[self taskInfo] inputTracks] objectAtIndex:0] document] title]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));

		// PERFORMER
		temp	= [NSString stringWithFormat:@"PERFORMER \"%@\"\n", [[[[[self taskInfo] inputTracks] objectAtIndex:0] document] artist]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));

		// FILE
		temp	= [NSString stringWithFormat:@"FILE \"%@\" %@\n", [[self outputFilename] lastPathComponent], [self cueSheetFormatName]];
		buf		= [temp fileSystemRepresentation];
		bytesWritten = write(fd, buf, strlen(buf));
		NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));
		
		for(i = 0; i < [[[self taskInfo] inputTracks] count]; ++i) {
			currentTrack = [[[self taskInfo] inputTracks] objectAtIndex:i];

			// TRACK xx
			temp	= [NSString stringWithFormat:@"  TRACK %.2lu AUDIO\n", (unsigned long)[currentTrack number]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));

			// ISRC
			if(nil != [currentTrack ISRC]) {
				temp	= [NSString stringWithFormat:@"    ISRC %@\n", [currentTrack ISRC]];
				buf		= [temp UTF8String];
				bytesWritten = write(fd, buf, strlen(buf));
				NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));
			}

			// TITLE
			temp	= [NSString stringWithFormat:@"    TITLE \"%@\"\n", [currentTrack title]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));

			// PERFORMER
			if(nil != [currentTrack artist]) {
				temp	= [NSString stringWithFormat:@"    PERFORMER \"%@\"\n", [currentTrack artist]];
				buf		= [temp UTF8String];
				bytesWritten = write(fd, buf, strlen(buf));
				NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));
			}
			
			// INDEX
			temp	= [NSString stringWithFormat:@"    INDEX 01 %.2u:%.2u:%.2u\n", m, s, f];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			NSAssert(-1 != bytesWritten, NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @""));
			
			// Update times
			f += [currentTrack frame];
			while(75 <= f) {
				f -= 75;
				++s;
			}
			
			s += [currentTrack second];
			while(60 <= s) {
				s -= 60;
				++m;
			}
			
			m += [currentTrack minute];
		}
	}


	@finally {
		// And close it
		if(-1 != fd) {
			int result = close(fd);
			NSAssert(-1 != result, NSLocalizedStringFromTable(@"Unable to close the cue sheet.", @"Exceptions", @""));
		}
	}
}

@end

@implementation EncoderTask (Private)

- (void)			writeTags							{}

- (void) touchOutputFile
{
	NSNumber		*permissions	= [NSNumber numberWithUnsignedLong:S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH];
	NSDictionary	*attributes		= [NSDictionary dictionaryWithObject:permissions forKey:NSFilePosixPermissions];	
	BOOL			result			= [[NSFileManager defaultManager] createFileAtPath:[self outputFilename] contents:nil attributes:attributes];
	NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @""));	
}

- (NSString *) generateCustomBasenameUsingMetadata:(AudioMetadata *)metadata settings:(NSDictionary *)settings substitutions:(NSDictionary *)substitutions
{
	NSString			*basename			= nil;
	NSMutableString		*customPath			= [NSMutableString stringWithCapacity:100];
	NSString			*customNamingScheme = [settings objectForKey:@"formatString"];
	
	// Get the elements needed to build the pathname
	NSNumber			*discNumber			= [metadata discNumber];
	NSNumber			*discTotal			= [metadata discTotal];
	NSString			*albumArtist		= [metadata albumArtist];
	NSString			*albumTitle			= [metadata albumTitle];
	NSString			*albumGenre			= [metadata albumGenre];
	NSString			*albumYear			= [metadata albumDate];
	NSString			*albumComposer		= [metadata albumComposer];
	NSString			*albumComment		= [metadata albumComment];
	NSNumber			*trackNumber		= [metadata trackNumber];
	NSNumber			*trackTotal			= [metadata trackTotal];
	NSString			*trackArtist		= [metadata trackArtist];
	NSString			*trackTitle			= [metadata trackTitle];
	NSString			*trackGenre			= [metadata trackGenre];
	NSString			*trackYear			= [metadata trackDate];
	NSString			*trackComposer		= [metadata trackComposer];
	NSString			*trackComment		= [metadata trackComment];
	NSString			*sourceFilename		= [[[[self taskInfo] inputFilenameAtInputFileIndex] lastPathComponent] stringByDeletingPathExtension];
	
	// Fallback to disc if specified in preferences
	if([[settings  objectForKey:@"useNamingFallback"] boolValue]) {
		if(nil == trackArtist)
			trackArtist = albumArtist;
		if(nil == trackGenre)
			trackGenre = albumGenre;
		if(nil == trackYear)
			trackYear = albumYear;
		if(nil == trackComposer)
			trackComposer = albumComposer;
		if(nil == trackComment)
			trackComment = albumComment;
	}
	
	if(nil == customNamingScheme)
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"The custom naming string appears to be invalid." userInfo:nil];
	else
		[customPath setString:customNamingScheme];
	
	if(nil == discNumber)
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[NSString stringWithFormat:@"%u", [discNumber intValue]] options:0 range:NSMakeRange(0, [customPath length])];					

	if(nil == discTotal)
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:[NSString stringWithFormat:@"%u", [discTotal intValue]] options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == albumArtist)
		[customPath replaceOccurrencesOfString:@"{albumArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumArtist}" withString:MakeStringSafeForFilename(albumArtist) options:0 range:NSMakeRange(0, [customPath length])];					

	if(nil == albumTitle)
		[customPath replaceOccurrencesOfString:@"{albumTitle}" withString:@"Unknown Disc" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumTitle}" withString:MakeStringSafeForFilename(albumTitle) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == albumGenre)
		[customPath replaceOccurrencesOfString:@"{albumGenre}" withString:@"Unknown Genre" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumGenre}" withString:MakeStringSafeForFilename(albumGenre) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == albumYear)
		[customPath replaceOccurrencesOfString:@"{albumDate}" withString:@"Unknown Year" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumDate}" withString:[NSString stringWithFormat:@"%u", [albumYear intValue]] options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == albumComposer)
		[customPath replaceOccurrencesOfString:@"{albumComposer}" withString:@"Unknown Composer" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumComposer}" withString:MakeStringSafeForFilename(albumComposer) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == albumComment)
		[customPath replaceOccurrencesOfString:@"{albumComment}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{albumComment}" withString:MakeStringSafeForFilename(albumComment) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == trackNumber)
		[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else {
		if([[settings objectForKey:@"useTwoDigitTrackNumbers"] boolValue])
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%02u", [trackNumber intValue]] options:0 range:NSMakeRange(0, [customPath length])];
		else
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%u", [trackNumber intValue]] options:0 range:NSMakeRange(0, [customPath length])];
	}
	
	if(nil == trackTotal)
		[customPath replaceOccurrencesOfString:@"{trackTotal}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else {
		if([[settings objectForKey:@"useTwoDigitTrackNumbers"] boolValue])
			[customPath replaceOccurrencesOfString:@"{trackTotal}" withString:[NSString stringWithFormat:@"%02u", [trackTotal intValue]] options:0 range:NSMakeRange(0, [customPath length])];
		else
			[customPath replaceOccurrencesOfString:@"{trackTotal}" withString:[NSString stringWithFormat:@"%u", [trackTotal intValue]] options:0 range:NSMakeRange(0, [customPath length])];
	}
	
	if(nil == trackArtist)
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:MakeStringSafeForFilename(trackArtist) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == trackTitle)
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"") options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:MakeStringSafeForFilename(trackTitle) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == trackGenre)
		[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"Unknown Genre" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:MakeStringSafeForFilename(trackGenre) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == trackYear)
		[customPath replaceOccurrencesOfString:@"{trackDate}" withString:@"Unknown Year" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackDate}" withString:MakeStringSafeForFilename(trackYear) options:0 range:NSMakeRange(0, [customPath length])];

	if(nil == trackComposer)
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:@"Unknown Composer" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:MakeStringSafeForFilename(trackComposer) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == trackComment)
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:MakeStringSafeForFilename(trackComment) options:0 range:NSMakeRange(0, [customPath length])];
	
	if(nil == sourceFilename)
		[customPath replaceOccurrencesOfString:@"{sourceFilename}" withString:@"" options:0 range:NSMakeRange(0, [customPath length])];
	else
		[customPath replaceOccurrencesOfString:@"{sourceFilename}" withString:MakeStringSafeForFilename(sourceFilename) options:0 range:NSMakeRange(0, [customPath length])];
	
	// Perform additional substitutions as necessary
	if(nil != substitutions) {
		NSEnumerator	*enumerator			= [substitutions keyEnumerator];
		id				key;
		
		while((key = [enumerator nextObject]))
			[customPath replaceOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key] withString:MakeStringSafeForFilename([substitutions valueForKey:key]) options:0 range:NSMakeRange(0, [customPath length])];
	}
	
	basename = customPath;

	return [[basename retain] autorelease];
}

- (NSString *) generateStandardBasenameUsingMetadata:(AudioMetadata *)metadata
{
	NSString	*basename	= nil;
	
	// Use standard iTunes-style naming for compilations: "Compilations/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	if([metadata compilation]) {
		NSString			*path;
		
		NSString			*albumTitle			= [metadata albumTitle];
		NSString			*trackTitle			= [metadata trackTitle];
		
		if(nil == albumTitle)
			albumTitle = NSLocalizedStringFromTable(@"Unknown Album", @"CompactDisc", @"");
		if(nil == trackTitle)
			trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		
		path = [NSString stringWithFormat:@"%@/%@", NSLocalizedStringFromTable(@"Compilations", @"CompactDisc", @""),MakeStringSafeForFilename(albumTitle)]; 
		
		if(nil == [metadata discNumber])
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[metadata trackNumber] intValue], MakeStringSafeForFilename(trackTitle)];
		else
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[metadata discNumber] intValue], [[metadata trackNumber] intValue], MakeStringSafeForFilename(trackTitle)];
	}
	// Use standard iTunes-style naming: "Artist/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else {
		NSString			*path;
		
		NSString			*albumArtist		= [metadata albumArtist];
		NSString			*trackArtist		= [metadata trackArtist];
		NSString			*artist;
		NSString			*albumTitle			= [metadata albumTitle];
		NSString			*trackTitle			= [metadata trackTitle];
		
		artist = trackArtist;
		if(nil == artist) {
			artist = albumArtist;
			if(nil == artist)
				artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
		}
		if(nil == albumTitle)
			albumTitle = NSLocalizedStringFromTable(@"Unknown Album", @"CompactDisc", @"");
		if(nil == trackTitle)
			trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		
		path = [NSString stringWithFormat:@"%@/%@", MakeStringSafeForFilename(artist), MakeStringSafeForFilename(albumTitle)]; 
		
		if(nil == [metadata discNumber])
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[metadata trackNumber] intValue], MakeStringSafeForFilename(trackTitle)];
		else
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[metadata discNumber] intValue], [[metadata trackNumber] intValue], MakeStringSafeForFilename(trackTitle)];
	}
	
	return [[basename retain] autorelease];
}

@end

@implementation EncoderTask (iTunesAdditions)

- (BOOL)			formatIsValidForiTunes			{ return NO; }

@end
