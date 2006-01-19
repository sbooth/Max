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

#import "PCMGeneratingTask.h"
#import "MissingResourceException.h"
#import "MallocException.h"
#import "IOException.h"

#include <paths.h>			//_PATH_TMP
#include <unistd.h>			// mkstemp, unlink

#define TEMPFILE_PATTERN	"MaxXXXXXX.raw"

@implementation PCMGeneratingTask

+ (void)initialize
{
	NSString					*defaultsValuesPath;
    NSDictionary				*defaultsValuesDictionary;
    
	@try {
		defaultsValuesPath = [[NSBundle mainBundle] pathForResource:@"PCMGeneratingTaskDefaults" ofType:@"plist"];
		if(nil == defaultsValuesPath) {
			@throw [MissingResourceException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to load '%@'", @"Exceptions", @""), @"PCMGeneratingTaskDefaults.plist"] userInfo:nil];
		}
		defaultsValuesDictionary = [NSDictionary dictionaryWithContentsOfFile:defaultsValuesPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsValuesDictionary];
	}
	
	@catch(NSException *exception) {
		displayExceptionAlert(exception);
	}
	
	@finally {
	}	
}

- (id) initWithMetadata:(AudioMetadata *)metadata
{
	char				*path			= NULL;
	const char			*tmpDir;
	ssize_t				tmpDirLen;
	ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);

	if((self = [super init])) {
		
		_metadata = [metadata retain];
		
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
			tmpDir = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] stringByAppendingString:@"/"] UTF8String];
		}
		else {
			tmpDir = _PATH_TMP;
		}

		// Create and open the output file
		tmpDirLen	= strlen(tmpDir);
		path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
		if(NULL == path) {
			@throw [MallocException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to allocate memory (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
		}
		memcpy(path, tmpDir, tmpDirLen);
		memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
		path[tmpDirLen + patternLen] = '\0';
		
		_out = mkstemps(path, 4);
		if(-1 == _out) {
			@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to create the output file '%s' (%i:%s)", @"Exceptions", @""), path, errno, strerror(errno)] userInfo:nil];
		}
		
		_fileClosed			= NO;
		_outputFilename		= [[NSString stringWithUTF8String:path] retain];
		
		free(path);
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_metadata release];
	
	[self closeOutputFile];
	[self removeOutputFile];
	
	[_outputFilename release];	
	
	[super dealloc];
}

- (void) removeOutputFile
{
	// Delete output file
	if(-1 == unlink([_outputFilename UTF8String])) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to delete temporary file '%@' (%i:%s)", @"Exceptions", @""), _outputFilename, errno, strerror(errno)] userInfo:nil];
	}	
}

- (void) closeOutputFile
{
	if(YES == _fileClosed) {
		return;
	}
	
	// Close output file
	if(-1 == close(_out)) {
		@throw [IOException exceptionWithReason:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to close temporary file (%i:%s)", @"Exceptions", @""), errno, strerror(errno)] userInfo:nil];
	}
	
	_fileClosed = YES;
}

- (AudioMetadata *)		metadata							{ return _metadata; }
- (int)					getOutputFile						{ return _out; }
- (NSString *)			getOutputFilename					{ return _outputFilename; }
- (NSString *)			description							{ return [_metadata description]; }
- (void)				run									{}
- (void)				stop								{}

@end
