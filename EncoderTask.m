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
#import "TaskMaster.h"
#import "MallocException.h"
#import "IOException.h"
#import "StopException.h"
#import "FileFormatNotSupportedException.h"
#import "MissingResourceException.h"
#import "UtilityFunctions.h"

@interface EncoderTask (Private)
- (void) touchOutputFile;
@end

@implementation EncoderTask

+ (void) initialize
{
	NSString				*defaultsValuesPath;
    NSDictionary			*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"EncoderTaskDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"EncoderTaskDefaults.plist" forKey:@"filename"]];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
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
			[track encodeCompleted];
			if(NO == [[track encodeInProgress] boolValue]) {
				[track setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
			}
		}

		[_tracks release];
	}
	
	if(nil != _connection) {
		[_connection release];
	}

	if(nil != _encoder) {
		[(NSObject *)_encoder release];
	}
	
	if(nil != _outputFilename) {
		[_outputFilename release];
	}	

	[_task release];
	
	[super dealloc];
}

- (NSString *)		outputFilename					{ return _outputFilename; }
- (NSString *)		inputFilename					{ return [_task outputFilename]; }
- (NSString *)		outputFormat					{ return nil; }
- (NSArray *)		tracks							{ return _tracks; }
- (NSString *)		extension						{ return nil; }
- (void)			writeTags						{}
- (NSString *)		description						{ return (nil == [_task metadata] ? @"fnord" : [[_task metadata] description]); }
- (NSString *)		settings						{ return (nil == _encoder ? @"fnord" : [_encoder settings]); }
- (BOOL)			formatLegalForCueSheet			{ return NO; }
- (NSString *)		cueSheetFormatName				{ return nil; }

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
	if(nil != _outputFilename && -1 == unlink([_outputFilename UTF8String])) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the output file", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}	
}

- (void) touchOutputFile
{
	int fd = -1;
	
	if(nil != _outputFilename) {
		@try {
			// Create the file (don't overwrite)
			fd = open([_outputFilename UTF8String], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
			if(-1 == fd) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
		
		@finally {
			// And close it
			if(-1 != fd && -1 == close(fd)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the output file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}
	}	
}

- (void) run
{
	NSString				*basename;
	NSMutableDictionary		*substitutions		= [NSMutableDictionary dictionaryWithCapacity:1];
	NSPort					*port1				= [NSPort port];
	NSPort					*port2				= [NSPort port];
	NSArray					*portArray			= nil;
	
	// Determine whether to convert in place
	if([_task isKindOfClass:[ConverterTask class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"convertInPlace"]) {
		basename = [[(ConverterTask *)_task inputFilename] stringByDeletingPathExtension];
	}
	else {
		// Set up the additional key/value pairs to be substituted
		[substitutions setObject:[self outputFormat] forKey:@"fileFormat"];
		basename = [[_task metadata] outputBasenameWithSubstitutions:substitutions];
		
		// Create the directory hierarchy if required
		createDirectoryStructure(basename);
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
	[[TaskMaster sharedController] encodeDidStart:self]; 
}

- (void) setStopped 
{
	[super setStopped]; 
	[_connection invalidate];
	[[TaskMaster sharedController] encodeDidStop:self]; 
}

- (void) setCompleted 
{
	@try {
		if(nil != [_task metadata]) {
			[self writeTags];
		}
		
		[super setCompleted]; 
		[_connection invalidate];
		[[TaskMaster sharedController] encodeDidComplete:self]; 
		
		// Delete input file if requested
		if([_task isKindOfClass:[ConverterTask class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"deleteAfterConversion"]) {
			if(-1 == unlink([[(ConverterTask *)_task inputFilename] UTF8String])) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}	
		}

		// Generate cue sheet
		if(nil != _tracks && [[NSUserDefaults standardUserDefaults] boolForKey:@"singleFileOutput"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"generateCueSheet"]) {
			if([self formatLegalForCueSheet]) {
				[self generateCueSheet];
			}
			else {
				@throw [FileFormatNotSupportedException exceptionWithReason:NSLocalizedStringFromTable(@"Cue sheets not supported for this output format", @"Exceptions", @"")
																   userInfo:[NSDictionary dictionaryWithObject:[self outputFormat] forKey:@"fileFormat"]];
			}
		}
	}
	
	@catch(NSException *e) {
		displayExceptionAlert(e);
	}
}

- (void) stop
{
	if([self started]) {
		[self setShouldStop];
	}
	else {
		[_connection invalidate];
		[[TaskMaster sharedController] encodeDidStop:self];
	}
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
		fd = open([cueSheetFilename UTF8String], O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
		if(-1 == fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create the cue sheet", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// REM
		bundleVersion	= [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		temp			= [NSString stringWithFormat:@"REM File create by Max %@\n", bundleVersion];
		buf				= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// TITLE
		temp	= [NSString stringWithFormat:@"TITLE \"%@\"\n", [[[_tracks objectAtIndex:0] getCompactDiscDocument] valueForKey:@"title"]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// PERFORMER
		temp	= [NSString stringWithFormat:@"PERFORMER \"%@\"\n", [[[_tracks objectAtIndex:0] getCompactDiscDocument] valueForKey:@"artist"]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}

		// FILE
		temp	= [NSString stringWithFormat:@"FILE \"%@\" %@\n", [_outputFilename lastPathComponent], [self cueSheetFormatName]];
		buf		= [temp UTF8String];
		bytesWritten = write(fd, buf, strlen(buf));
		if(-1 == bytesWritten) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		for(i = 0; i < [_tracks count]; ++i) {
			currentTrack = [_tracks objectAtIndex:i];

			// TRACK xx
			temp	= [NSString stringWithFormat:@"  TRACK %.02u AUDIO\n", [[currentTrack valueForKey:@"number"] intValue]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// ISRC
			temp	= [NSString stringWithFormat:@"    ISRC %@\n", [currentTrack valueForKey:@"ISRC"]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// TITLE
			temp	= [NSString stringWithFormat:@"    TITLE \"%@\"\n", [currentTrack valueForKey:@"title"]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// PERFORMER
			temp	= [NSString stringWithFormat:@"    PERFORMER \"%@\"\n", [currentTrack valueForKey:@"artist"]];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			// INDEX
			temp	= [NSString stringWithFormat:@"    INDEX 01 %.2u:%.2u:%.2u\n", m, s, f];
			buf		= [temp UTF8String];
			bytesWritten = write(fd, buf, strlen(buf));
			if(-1 == bytesWritten) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to write to the cue sheet", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Update times
			f += [currentTrack getFrame];
			while(75 < f) {
				f /= 75;
				++s;
			}
			
			s += [currentTrack getSecond];
			while(60 < s) {
				s /= 60;
				++m;
			}
			
			m += [currentTrack getMinute];
		}
	}


	@finally {
		// And close it
		if(-1 != fd && -1 == close(fd)) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the cue sheet", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
	}
}

@end
