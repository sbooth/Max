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
#import "ConverterTask.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "FileFormatNotSupportedException.h"
#import "MissingResourceException.h"
#import "UtilityFunctions.h"

#include <sys/stat.h>		// stat
#include <unistd.h>			// mkstemp, unlink

@interface EncoderTask (Private)
- (void)		touchOutputFile;
- (NSString *)	generateStandardBasenameUsingMetadata:(AudioMetadata *)metadata;
- (NSString *)	generateCustomBasenameUsingMetadata:(AudioMetadata *)metadata withSubstitutions:(NSDictionary *)substitutions;
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

+ (void) initialize
{
	NSString				*defaultsValuesPath;
    NSDictionary			*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"EncoderTaskDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Your installation of Max appears to be incomplete.", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"EncoderTaskDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"General", @"")];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"An error occurred while initializing the %@ class.", @"Exceptions", @""), @"EncoderTask"]];
		[alert setInformativeText:[exception reason]];
		[alert setAlertStyle:NSWarningAlertStyle];		
		[alert runModal];
	}
}

- (id) initWithTask:(PCMGeneratingTask *)task
{
	if((self = [super init])) {
		_connection					= nil;
		_encoder					= nil;
		_task						= [task retain];
		_outputFilename				= nil;
		_tracks						= nil;
		_writeSettingsToComment		= [[NSUserDefaults standardUserDefaults] boolForKey:@"saveEncoderSettingsInComment"];
	
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	NSEnumerator	*enumerator;
	Track			*track;

	if(nil != _tracks) {
		enumerator = [_tracks objectEnumerator];
	
		while((track = [enumerator nextObject])) {
			if(NO == [track ripInProgress] && NO == [track encodeInProgress]) {
				[track setSelected:NO];
			}
		}

		[_tracks release];
	}
	
	[_connection release];
	[(NSObject *)_encoder release];
	[_outputFilename release];
	[_task release];
	
	[super dealloc];
}

- (NSString *)		outputFilename						{ return _outputFilename; }
- (NSString *)		inputFilename						{ return [_task outputFilename]; }
- (NSString *)		outputFormat						{ return nil; }
- (unsigned)		countOfTracks						{ return [_tracks count]; }
- (Track *)			objectInTracksAtIndex:(unsigned)idx { return [_tracks objectAtIndex:idx]; }
- (NSString *)		extension							{ return nil; }
- (AudioMetadata *) metadata							{ return [_task metadata]; }
- (void)			writeTags							{}
- (NSString *)		description							{ return (nil == [_task metadata] ? @"fnord" : [[_task metadata] description]); }
- (NSString *)		settings							{ return (nil == _encoder ? @"fnord" : [_encoder settings]); }
- (BOOL)			formatLegalForCueSheet				{ return NO; }
- (NSString *)		cueSheetFormatName					{ return nil; }

- (NSString *)		outputDirectory						{ return _outputDirectory; }
- (void)			setOutputDirectory:(NSString *)outputDirectory { [_outputDirectory release]; _outputDirectory = [outputDirectory retain]; }

- (BOOL)			overwriteExistingFiles				{ return _overwriteExistingFiles; }
- (void)			setOverwriteExistingFiles:(BOOL)overwriteExistingFiles { _overwriteExistingFiles = overwriteExistingFiles; }

- (NSDictionary *)	fileNamingFormat					{ return _fileNamingFormat; }
- (void)			setFileNamingFormat:(NSDictionary *)fileNamingFormat { [_fileNamingFormat release]; _fileNamingFormat = [fileNamingFormat retain]; }

- (NSDictionary *)	postProcessingOptions				{ return _postProcessingOptions; }
- (void)			setPostProcessingOptions:(NSDictionary *)postProcessingOptions { [_postProcessingOptions release]; _postProcessingOptions = [postProcessingOptions retain]; }

//- (void)			insertObject:(Track *)track inTracksAtIndex:(unsigned)idx		{ [_tracks insertObject:track atIndex:idx]; }
//- (void)			removeObjectFromTracksAtIndex:(unsigned)idx					{ [_tracks removeObjectAtIndex:idx]; }
- (void) setTracks:(NSArray *)tracks
{
	NSEnumerator	*enumerator;
	Track			*track;

	if(nil != _tracks) {
		[_tracks release];
	}
	
	_tracks			= [tracks retain];
	enumerator		= [_tracks objectEnumerator];
	
	while((track = [enumerator nextObject])) {
		[track encodeStarted];
	}
}

- (void) removeOutputFile
{
	if(nil != _outputFilename && -1 == unlink([_outputFilename fileSystemRepresentation])) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}	
}

- (void) touchOutputFile
{
	int fd = -1;
	
	if(nil != _outputFilename) {
		@try {
			// Create the file (don't overwrite)
			fd = open([_outputFilename fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
			if(-1 == fd) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		@finally {
			// And close it
			if(-1 != fd && -1 == close(fd)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
	}	
}

- (void) run
{
	NSString				*basename;
	NSMutableDictionary		*substitutions		= [NSMutableDictionary dictionary];
	NSPort					*port1				= [NSPort port];
	NSPort					*port2				= [NSPort port];
	NSArray					*portArray			= nil;
	
	// Determine whether to convert in place
	if([_task isKindOfClass:[ConverterTask class]] && nil == [self outputDirectory]) {
		basename = [[(ConverterTask *)_task inputFilename] stringByDeletingPathExtension];
	}
	// Use the filename if no metadata was found
	else if([_task isKindOfClass:[ConverterTask class]] && [[_task metadata] isEmpty]) {
		basename = [NSString stringWithFormat:@"%@/%@", [[self outputDirectory] stringByExpandingTildeInPath], [[[(ConverterTask *)_task inputFilename] lastPathComponent] stringByDeletingPathExtension]];
	}
	// Use the standard file naming format
	else if(nil == [self fileNamingFormat]) {
		basename = [NSString stringWithFormat:@"%@/%@", [[self outputDirectory] stringByExpandingTildeInPath], [self generateStandardBasenameUsingMetadata:[_task metadata]]];

		// Create the directory hierarchy if required
		createDirectoryStructure(basename);
	}
	// Use a custom file naming format
	else {
		// Set up the additional key/value pairs to be substituted
		[substitutions setObject:[self outputFormat] forKey:@"fileFormat"];
		basename = [NSString stringWithFormat:@"%@/%@", [[self outputDirectory] stringByExpandingTildeInPath], [self generateCustomBasenameUsingMetadata:[_task metadata] withSubstitutions:substitutions]];
		
		// Create the directory hierarchy if required
		createDirectoryStructure(basename);
	}
	
	// Save album art if desired
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"saveAlbumArtToFile"] && nil != [[_task metadata] albumArt]) {
		NSBitmapImageFileType	fileType;
		NSString				*extension, *namingScheme;
		NSData					*bitmapData;
		NSString				*bitmapBasename, *bitmapFilename;

		switch([[NSUserDefaults standardUserDefaults] integerForKey:@"albumArtFileFormat"]) {
			case kTIFFFileFormatMenuItemTag:		fileType = NSTIFFFileType;			extension = @"tiff";		break;
			case kBMPFileFormatMenuItemTag:			fileType = NSBMPFileType;			extension = @"bmp";			break;
			case kGIFFileFormatMenuItemTag:			fileType = NSGIFFileType;			extension = @"gif";			break;
			case kJPEGFileFormatMenuItemTag:		fileType = NSJPEGFileType;			extension = @"jpeg";		break;
			case kPNGFileFormatMenuItemTag:			fileType = NSPNGFileType;			extension = @"png";			break;
			case kJPEG200FileFormatMenuItemTag:		fileType = NSJPEG2000FileType;		extension = @"jpeg";		break;
				
		}

		namingScheme		= [[NSUserDefaults standardUserDefaults] stringForKey:@"albumArtNamingScheme"];
		if(nil == namingScheme) {
			namingScheme = @"cover";
		}
		
		bitmapData			= getBitmapDataForImage([[_task metadata] albumArt], fileType);
		bitmapBasename		= [[basename stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[_task metadata] replaceKeywordsInString:makeStringSafeForFilename(namingScheme)]];
		//bitmapFilename		= generateUniqueFilename(bitmapBasename, extension);
		bitmapFilename		= [bitmapBasename stringByAppendingPathExtension:extension];

		if(NO == [[NSFileManager defaultManager] fileExistsAtPath:bitmapFilename]) {
			[bitmapData writeToFile:bitmapFilename atomically:NO];		
		}
	}
	
	// Check if output file exists
	if([self overwriteExistingFiles] && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@.%@", basename, [self extension]]]) {
		NSString		*filename		= [NSString stringWithFormat:@"%@.%@", basename, [self extension]];
		struct stat		sourceStat;
		
		// Delete output file if it exists
		if(0 == stat([filename fileSystemRepresentation], &sourceStat) && -1 == unlink([filename fileSystemRepresentation])) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the output file.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}	
		
	}
			
	// Generate a unique filename and touch the file
	_outputFilename = [generateUniqueFilename(basename, [self extension]) retain];
	[self touchOutputFile];
	
	_connection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[_connection setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	
	[super setStarted];
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:_encoderClass withObject:portArray];
}

- (void) encoderReady:(id)anObject
{
	_encoder = [(NSObject*) anObject retain];
    [anObject setProtocolForProxy:@protocol(EncoderMethods)];
	[anObject encodeToFile:[self outputFilename]];
}

- (void) setStarted
{
	[super setStarted];
	[[EncoderController sharedController] encoderTaskDidStart:self]; 
}

- (void) setStopped 
{
	NSEnumerator	*enumerator;
	Track			*track;

	[super setStopped]; 
	
	[_connection invalidate];
	[_connection release];
	_connection = nil;

	if(nil != _tracks) {
		enumerator = [_tracks objectEnumerator];			
		while((track = [enumerator nextObject])) {
			[track encodeCompleted];
		}
	}
	
	[[EncoderController sharedController] encoderTaskDidStop:self]; 
}

- (void) setCompleted 
{
	NSEnumerator	*enumerator;
	Track			*track;
	
	@try {
		if(nil != [_task metadata]) {
			[self writeTags];
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
		[super setCompleted];
		
		[_connection invalidate];
		[_connection release];
		_connection = nil;
		
		// Delete input file if requested
		if([_task isKindOfClass:[ConverterTask class]] && [[[self userInfo] objectForKey:@"deleteSourceFiles"] boolValue]) {
			if(-1 == unlink([[(ConverterTask *)_task inputFilename] fileSystemRepresentation])) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the input file.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}	
		}

		// Generate cue sheet
		if(nil != _tracks && [[NSUserDefaults standardUserDefaults] boolForKey:@"singleFileOutput"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"generateCueSheet"]) {
			if([self formatLegalForCueSheet]) {
				[self generateCueSheet];
			}
			/*else {
				@throw [FileFormatNotSupportedException exceptionWithReason:NSLocalizedStringFromTable(@"Cue sheets are not supported for this output format.", @"Exceptions", @"")
																   userInfo:[NSDictionary dictionaryWithObject:[self outputFormat] forKey:@"fileFormat"]];
			}*/
		}

		if(nil != _tracks) {
			enumerator = [_tracks objectEnumerator];			
			while((track = [enumerator nextObject])) {
				[track encodeCompleted];
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
		[self setShouldStop];
	}
	else {
		[self setStopped];
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
	
	if(nil == _tracks) {
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
		temp	= [NSString stringWithFormat:@"TITLE \"%@\"\n", [[[_tracks objectAtIndex:0] document] title]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// PERFORMER
		temp	= [NSString stringWithFormat:@"PERFORMER \"%@\"\n", [[[_tracks objectAtIndex:0] document] artist]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// FILE
		temp	= [NSString stringWithFormat:@"FILE \"%@\" %@\n", [_outputFilename lastPathComponent], [self cueSheetFormatName]];
		buf		= [temp fileSystemRepresentation];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet.", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(i = 0; i < [_tracks count]; ++i) {
			currentTrack = [_tracks objectAtIndex:i];

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
			while(75 < f) {
				f /= 75;
				++s;
			}
			
			s += [currentTrack second];
			while(60 < s) {
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

- (NSString *) generateCustomBasenameUsingMetadata:(AudioMetadata *)metadata withSubstitutions:(NSDictionary *)substitutions
{
	NSString			*basename			= nil;
	NSMutableString		*customPath			= [NSMutableString stringWithCapacity:100];
	NSString			*customNamingScheme = [[self fileNamingFormat] objectForKey:@"fileNamingFormat"];
	
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
	
	// Fallback to disc if specified in preferences
	if([[[self fileNamingFormat] objectForKey:@"useFallback"] boolValue]) {
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
		if([[[self fileNamingFormat] objectForKey:@"useTwoDigitTrackNumbers"] boolValue]) {
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
	NSString	*basename	= nil;;
	
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
