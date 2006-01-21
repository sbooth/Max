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
			@throw [MissingResourceException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to load required resource", @"Exceptions", @"")
														userInfo:[NSDictionary dictionaryWithObject:@"PCMGeneratingTaskDefaults.plist" forKey:@"filename"]];
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
	int					fd;
	char				*path			= NULL;
	const char			*tmpDir;
	ssize_t				tmpDirLen;
	ssize_t				patternLen		= strlen(TEMPFILE_PATTERN);

	if((self = [super init])) {
		
		@try {
			_metadata		= [metadata retain];

			if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomTmpDirectory"]) {
				tmpDir = [[[[NSUserDefaults standardUserDefaults] stringForKey:@"tmpDirectory"] stringByAppendingString:@"/"] UTF8String];
			}
			else {
				tmpDir = _PATH_TMP;
			}

			// Create and open the (temporary) output file
			tmpDirLen	= strlen(tmpDir);
			path		= malloc((tmpDirLen + patternLen + 1) *  sizeof(char));
			if(NULL == path) {
				@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") 
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			memcpy(path, tmpDir, tmpDirLen);
			memcpy(path + tmpDirLen, TEMPFILE_PATTERN, patternLen);
			path[tmpDirLen + patternLen] = '\0';
		
			// We're really only interested in the name of this file.  
			// Use mkstemps (instead of mktemp) to guarantee creation of a unique temp file
			fd = mkstemps(path, 4);
			if(-1 == fd) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create a temporary file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}

			if(-1 == close(fd)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the temporary file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			_outputFilename		= [[NSString stringWithUTF8String:path] retain];
		}
		
		@catch(NSException *exception) {
			@throw;
		}
		
		@finally {
			free(path);
		}
		
		return self;
	}
	
	return nil;
}

- (void) dealloc
{
	[_metadata release];
	[self removeOutputFile];
	[_outputFilename release];	
	
	[super dealloc];
}

- (void) removeOutputFile
{
	// Delete output file
	if(-1 == unlink([_outputFilename UTF8String])) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to delete the temporary file", @"Exceptions", @"") 
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithUTF8String:strerror(errno)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}	
}


- (AudioMetadata *)		metadata							{ return _metadata; }
- (NSString *)			outputFilename						{ return _outputFilename; }
- (NSString *)			description							{ return [_metadata description]; }
- (void)				run									{}
- (void)				stop								{}

@end
