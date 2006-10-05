/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
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
#import "FileConversionSettingsSheet.h"

#import "UtilityFunctions.h"

#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "FileFormatNotSupportedException.h"
#import "MissingResourceException.h"

#include <sys/stat.h>		// stat
#include <unistd.h>			// mkstemp, unlink

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
	NSEnumerator	*enumerator;
	Track			*track;

	if(nil != [[self taskInfo] inputTracks]) {
		enumerator = [[[self taskInfo] inputTracks] objectEnumerator];
	
		while((track = [enumerator nextObject])) {
			if(NO == [track ripInProgress] && NO == [track encodeInProgress]) {
				[track setSelected:NO];
			}
		}
	}
	
	[_connection release];				_connection = nil;
	[(NSObject *)_encoder release];		_encoder = nil;
	[_outputFilename release];			_outputFilename = nil;
	
	[super dealloc];
}

- (NSString *)		description
{
	NSString		*result		= nil;
	
	result =  [[[self taskInfo] metadata] description];
	if(nil == result) {
		result = [[[[self taskInfo] inputFilenameAtInputFileIndex] lastPathComponent] stringByDeletingPathExtension];
	}
	
	return result;
}

- (NSString *)		outputFormatName					{ return nil; }
- (NSString *)		fileExtension						{ return nil; }

- (NSDictionary *)	encoderSettings						{ return [[_encoderSettings retain] autorelease]; }
- (void)			setEncoderSettings:(NSDictionary *)encoderSettings 	{ [_encoderSettings release]; _encoderSettings = [encoderSettings retain]; }

- (NSString *)		encoderSettingsString				{ return [_encoder settingsString]; }

- (void)			encoderReady:(id)anObject
{
	_encoder = [(NSObject*) anObject retain];
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
	if(nil == [[self taskInfo] inputTracks] && nil == [[[self taskInfo] settings] objectForKey:@"outputDirectory"]) {
		basename = [[[self taskInfo] inputFilenameAtInputFileIndex] stringByDeletingPathExtension];
	}
	// Use the input filename if we're not encoding in place and no metadata was found
	else if(nil == [[self taskInfo] inputTracks] && [[[self taskInfo] metadata] isEmpty]) {
		basename = [NSString stringWithFormat:@"%@/%@",
			[[[[self taskInfo] settings] objectForKey:@"outputDirectory"] stringByExpandingTildeInPath],
			[[[[self taskInfo] inputFilenameAtInputFileIndex] lastPathComponent] stringByDeletingPathExtension] ];

		// Create the directory hierarchy if required
		createDirectoryStructure(basename);
	}
	// Use the standard file naming format
	else if(nil == [[[self taskInfo] settings] objectForKey:@"outputFileNaming"]) {
		basename = [NSString stringWithFormat:@"%@/%@",
			[[[[self taskInfo] settings] objectForKey:@"outputDirectory"] stringByExpandingTildeInPath],
			[self generateStandardBasenameUsingMetadata:[[self taskInfo] metadata]] ];

		// Create the directory hierarchy if required
		createDirectoryStructure(basename);
	}
	// Use a custom file naming format
	else {
		NSDictionary				*outputFileNaming	= [[[self taskInfo] settings] objectForKey:@"outputFileNaming"];
		
		NSMutableDictionary		*substitutions		= [NSMutableDictionary dictionary];
		
		// Set up the additional key/value pairs to be substituted
		[substitutions setObject:[self outputFormatName] forKey:@"fileFormat"];
		basename = [NSString stringWithFormat:@"%@/%@",
			[[[[self taskInfo] settings] objectForKey:@"outputDirectory"] stringByExpandingTildeInPath],
			[self generateCustomBasenameUsingMetadata:[[self taskInfo] metadata] settings:outputFileNaming substitutions:substitutions] ];

		// Create the directory hierarchy if required
		createDirectoryStructure(basename);
	}
	
	// Save album art if desired
	if(nil != [[[self taskInfo] settings] objectForKey:@"albumArt"] && nil != [[[self taskInfo] metadata] albumArt]) {
		NSDictionary			*albumArtSettings;
		NSBitmapImageFileType	fileType;
		NSString				*extension, *namingScheme;
		NSData					*bitmapData;
		NSString				*bitmapBasename, *bitmapFilename;
		
		
		albumArtSettings	= [[[self taskInfo] settings] objectForKey:@"albumArt"];
		
		switch([[albumArtSettings objectForKey:@"extension"] intValue]) {
			case kTIFFFileFormatMenuItemTag:		fileType = NSTIFFFileType;			extension = @"tiff";		break;
			case kBMPFileFormatMenuItemTag:			fileType = NSBMPFileType;			extension = @"bmp";			break;
			case kGIFFileFormatMenuItemTag:			fileType = NSGIFFileType;			extension = @"gif";			break;
			case kJPEGFileFormatMenuItemTag:		fileType = NSJPEGFileType;			extension = @"jpeg";		break;
			case kPNGFileFormatMenuItemTag:			fileType = NSPNGFileType;			extension = @"png";			break;
			case kJPEG200FileFormatMenuItemTag:		fileType = NSJPEG2000FileType;		extension = @"jpeg";		break;
		}
		
		namingScheme		= [albumArtSettings objectForKey:@"formatString"];
		if(nil == namingScheme) {
			namingScheme = @"cover";
		}
		
		bitmapData			= getBitmapDataForImage([[[self taskInfo] metadata] albumArt], fileType);
		bitmapBasename		= [[[self outputFilename] stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[[self taskInfo] metadata] replaceKeywordsInString:makeStringSafeForFilename(namingScheme)]];
		//bitmapFilename		= generateUniqueFilename(bitmapBasename, extension);
		bitmapFilename		= [bitmapBasename stringByAppendingPathExtension:extension];
		
		// Don't overwrite existing files
		if(NO == [[NSFileManager defaultManager] fileExistsAtPath:bitmapFilename]) {
			[bitmapData writeToFile:bitmapFilename atomically:NO];		
		}
	}
	
	// Check if output file exists and delete if requested
	if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@.%@", basename, [self fileExtension]]] && [[[[self taskInfo] settings] objectForKey:@"overwriteOutputFiles"] boolValue]) {
		
		// TODO: Prompt whether to overwite
		if([[[[self taskInfo] settings] objectForKey:@"promptBeforeOverwritingOutputFiles"] boolValue]) {
			
		}
		
		NSString		*filename		= [NSString stringWithFormat:@"%@.%@", basename, [self fileExtension]];
		BOOL			result			= [[NSFileManager defaultManager] removeFileAtPath:filename handler:nil];
		NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") );
	}

	// Otherwise, generate a unique filename and touch the output file
	[self setOutputFilename:generateUniqueFilename(basename, [self fileExtension])];
	[self touchOutputFile];
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted:YES];
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_encoderClass withObject:portArray];
}

- (void) setStarted:(BOOL)started
{
	[super setStarted:YES];

	// Mark tracks as started
	if(nil != [[self taskInfo] inputTracks]) {
		NSArray			*tracks		= [[self taskInfo] inputTracks];
		unsigned		i;
		
		for(i = 0; i < [tracks count]; ++i) {
			[[tracks objectAtIndex:i] encodeStarted];
		}
	}

	[[EncoderController sharedController] encoderTaskDidStart:self]; 
}

- (void) setStopped:(BOOL)stopped
{
	[super setStopped:YES]; 
	
	[_connection invalidate];
	[_connection release];
	_connection = nil;

	// Mark tracks as complete
	if(nil != [[self taskInfo] inputTracks]) {
		NSArray			*tracks		= [[self taskInfo] inputTracks];
		unsigned		i;
		
		for(i = 0; i < [tracks count]; ++i) {
			[[tracks objectAtIndex:i] encodeCompleted];
		}
	}
	
	[[EncoderController sharedController] encoderTaskDidStop:self]; 
}

- (void) setCompleted:(BOOL)completed
{
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
					addFileToiTunesLibrary([self outputFilename], metadata);
				}				
			}
		}
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while tagging the file \"%@\".", @"Exceptions", @""), [[self outputFilename] lastPathComponent]]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
	
	@try {
		[super setCompleted:YES];
		
		[_connection invalidate];
		[_connection release];
		_connection = nil;
		
		// Delete input file if requested
		if(nil == [[self taskInfo] inputTracks] && [[[[self taskInfo] settings] objectForKey:@"deleteSourceFiles"] boolValue]) {
			NSArray			*filenames		= [[self taskInfo] inputFilenames];
			unsigned		i;
			BOOL			result;
			
			for(i = 0; i < [filenames count]; ++i) {
				result = [[NSFileManager defaultManager] removeFileAtPath:[filenames objectAtIndex:i] handler:nil];
				NSAssert(YES == result, NSLocalizedStringFromTable(@"Unable to delete the input file.", @"Exceptions", @""));
			}
		}

		// Generate cue sheet
		if(nil != [[self taskInfo] inputTracks] && [[NSUserDefaults standardUserDefaults] boolForKey:@"singleFileOutput"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"generateCueSheet"]) {
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
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while encoding the file \"%@\".", @"Exceptions", @""), [[self outputFilename] lastPathComponent]]];
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
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while encoding the file \"%@\".", @"Exceptions", @""), [[self outputFilename] lastPathComponent]]];
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
		cueSheetFilename = generateUniqueFilename([_outputFilename stringByDeletingPathExtension], @"cue");

		// Create the file (don't overwrite)
		fd = open([cueSheetFilename fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// REM
		bundleVersion	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
		temp			= [NSString stringWithFormat:@"REM File create by Max %@\n", bundleVersion];
		buf				= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// TITLE
		temp	= [NSString stringWithFormat:@"TITLE \"%@\"\n", [[[[[self taskInfo] inputTracks] objectAtIndex:0] document] title]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// PERFORMER
		temp	= [NSString stringWithFormat:@"PERFORMER \"%@\"\n", [[[[[self taskInfo] inputTracks] objectAtIndex:0] document] artist]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// FILE
		temp	= [NSString stringWithFormat:@"FILE \"%@\" %@\n", [[self outputFilename] lastPathComponent], [self cueSheetFormatName]];
		buf		= [temp fileSystemRepresentation];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(i = 0; i < [[[self taskInfo] inputTracks] count]; ++i) {
			currentTrack = [[[self taskInfo] inputTracks] objectAtIndex:i];

			// TRACK xx
			temp	= [NSString stringWithFormat:@"  TRACK %.02u AUDIO\n", [currentTrack number]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// ISRC
			if(nil != [currentTrack ISRC]) {
				temp	= [NSString stringWithFormat:@"    ISRC %@\n", [currentTrack ISRC]];
				buf		= [temp UTF8String];
				bytesWritten = write(fd, buf, strlen(buf));
				if(-1 == bytesWritten) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
												   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
				}
			}

			// TITLE
			temp	= [NSString stringWithFormat:@"    TITLE \"%@\"\n", [currentTrack title]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// PERFORMER
			temp	= [NSString stringWithFormat:@"    PERFORMER \"%@\"\n", [currentTrack artist]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// INDEX
			temp	= [NSString stringWithFormat:@"    INDEX 01 %.2u:%.2u:%.2u\n", m, s, f];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Update times
			f += [currentTrack frame];
			while(75 <= f) {
				f /= 75;
				++s;
			}
			
			s += [currentTrack second];
			while(60 <= s) {
				s /= 60;
				++m;
			}
			
			m += [currentTrack minute];
		}
	}


	@finally {
		// And close it
		if(-1 != fd && -1 == close(fd)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
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
	unsigned			discNumber			= [metadata discNumber];
	unsigned			discTotal			= [metadata discTotal];
	NSString			*albumArtist		= [metadata albumArtist];
	NSString			*albumTitle			= [metadata albumTitle];
	NSString			*albumGenre			= [metadata albumGenre];
	unsigned			albumYear			= [metadata albumYear];
	NSString			*albumComposer		= [metadata albumComposer];
	NSString			*albumComment		= [metadata albumComment];
	unsigned			trackNumber			= [metadata trackNumber];
	NSString			*trackArtist		= [metadata trackArtist];
	NSString			*trackTitle			= [metadata trackTitle];
	NSString			*trackGenre			= [metadata trackGenre];
	unsigned			trackYear			= [metadata trackYear];
	NSString			*trackComposer		= [metadata trackComposer];
	NSString			*trackComment		= [metadata trackComment];
	NSString			*sourceFilename		= [[[[self taskInfo] inputFilenameAtInputFileIndex] lastPathComponent] stringByDeletingPathExtension];
	
	// Fallback to disc if specified in preferences
	if([[settings  objectForKey:@"useNamingFallback"] boolValue]) {
		if(nil == trackArtist) {
			trackArtist = albumArtist;
		}
		if(nil == trackGenre) {
			trackGenre = albumGenre;
		}
		if(0 == trackYear) {
			trackYear = albumYear;
		}
		if(nil == trackComposer) {
			trackComposer = albumComposer;
		}
		if(nil == trackComment) {
			trackComment = albumComment;
		}
	}
	
	if(nil == customNamingScheme) {
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"The custom naming string appears to be invalid." userInfo:nil];
	}
	else {
		[customPath setString:customNamingScheme];
	}
	
	if(0 == discNumber) {
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[NSString stringWithFormat:@"%u", discNumber] options:nil range:NSMakeRange(0, [customPath length])];					
	}
	if(0 == discTotal) {
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{discTotal}" withString:[NSString stringWithFormat:@"%u", discTotal] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == albumArtist) {
		[customPath replaceOccurrencesOfString:@"{albumArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{albumArtist}" withString:makeStringSafeForFilename(albumArtist) options:nil range:NSMakeRange(0, [customPath length])];					
	}
	if(nil == albumTitle) {
		[customPath replaceOccurrencesOfString:@"{albumTitle}" withString:@"Unknown Disc" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{albumTitle}" withString:makeStringSafeForFilename(albumTitle) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == albumGenre) {
		[customPath replaceOccurrencesOfString:@"{albumGenre}" withString:@"Unknown Genre" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{albumGenre}" withString:makeStringSafeForFilename(albumGenre) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(0 == albumYear) {
		[customPath replaceOccurrencesOfString:@"{albumYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{albumYear}" withString:[NSString stringWithFormat:@"%u", albumYear] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == albumComposer) {
		[customPath replaceOccurrencesOfString:@"{albumComposer}" withString:@"Unknown Composer" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{albumComposer}" withString:makeStringSafeForFilename(albumComposer) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == albumComment) {
		[customPath replaceOccurrencesOfString:@"{albumComment}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{albumComment}" withString:makeStringSafeForFilename(albumComment) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(0 == trackNumber) {
		[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		if([[settings objectForKey:@"useTwoDigitTrackNumbers"] boolValue]) {
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%02u", trackNumber] options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%u", trackNumber] options:nil range:NSMakeRange(0, [customPath length])];
		}
	}
	if(nil == trackArtist) {
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackTitle) {
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"") options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:makeStringSafeForFilename(trackTitle) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackGenre) {
		[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:@"Unknown Genre" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackGenre}" withString:makeStringSafeForFilename(trackGenre) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(0 == trackYear) {
		[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[NSString stringWithFormat:@"%u", trackYear] options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackComposer) {
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:@"Unknown Composer" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackComposer}" withString:makeStringSafeForFilename(trackComposer) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == trackComment) {
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{trackComment}" withString:makeStringSafeForFilename(trackComment) options:nil range:NSMakeRange(0, [customPath length])];
	}
	if(nil == sourceFilename) {
		[customPath replaceOccurrencesOfString:@"{sourceFilename}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
	}
	else {
		[customPath replaceOccurrencesOfString:@"{sourceFilename}" withString:makeStringSafeForFilename(sourceFilename) options:nil range:NSMakeRange(0, [customPath length])];
	}
	
	// Perform additional substitutions as necessary
	if(nil != substitutions) {
		NSEnumerator	*enumerator			= [substitutions keyEnumerator];
		id				key;
		
		while((key = [enumerator nextObject])) {
			[customPath replaceOccurrencesOfString:[NSString stringWithFormat:@"{%@}", key] withString:makeStringSafeForFilename([substitutions valueForKey:key]) options:nil range:NSMakeRange(0, [customPath length])];
		}
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
		
		if(nil == albumTitle) {
			albumTitle = NSLocalizedStringFromTable(@"Unknown Album", @"CompactDisc", @"");
		}
		if(nil == trackTitle) {
			trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		}
		
		path = [NSString stringWithFormat:@"%@/%@", NSLocalizedStringFromTable(@"Compilations", @"CompactDisc", @""),makeStringSafeForFilename(albumTitle)]; 
		
		if(0 == [metadata discNumber]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [metadata trackNumber], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [metadata discNumber], [metadata trackNumber], makeStringSafeForFilename(trackTitle)];
		}
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
			if(nil == artist) {
				artist = NSLocalizedStringFromTable(@"Unknown Artist", @"CompactDisc", @"");
			}
		}
		if(nil == albumTitle) {
			albumTitle = NSLocalizedStringFromTable(@"Unknown Album", @"CompactDisc", @"");
		}
		if(nil == trackTitle) {
			trackTitle = NSLocalizedStringFromTable(@"Unknown Track", @"CompactDisc", @"");
		}
		
		path = [NSString stringWithFormat:@"%@/%@", makeStringSafeForFilename(artist), makeStringSafeForFilename(albumTitle)]; 
		
		if(0 == [metadata discNumber]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [metadata trackNumber], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [metadata discNumber], [metadata trackNumber], makeStringSafeForFilename(trackTitle)];
		}
	}
	
	return [[basename retain] autorelease];
}

@end

@implementation EncoderTask (iTunesAdditions)

- (BOOL)			formatIsValidForiTunes			{ return NO; }

@end
