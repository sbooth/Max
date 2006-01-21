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

#import "LibsndfileConverterTask.h"
#import "LibsndfileConverter.h"
#import "IOException.h"

#include "sndfile.h"

@implementation LibsndfileConverterTask

- (id) initWithInputFile:(NSString *)inputFilename metadata:(AudioMetadata *)metadata
{
	SF_INFO					info;
	SF_FORMAT_INFO			formatInfo;
	SNDFILE					*sndfile			= NULL;
	
	if((self = [super initWithInputFile:inputFilename metadata:metadata])) {
		
		@try {
			_converterClass = [LibsndfileConverter class];
			
			// Get information on the input file
			info.format = 0;
			
			sndfile = sf_open([_inputFilename UTF8String], SFM_READ, &info);
			if(NULL == sndfile) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
			
			// Get format info
			formatInfo.format = info.format;
			
			if(0 == sf_command(NULL, SFC_GET_FORMAT_INFO, &formatInfo, sizeof(formatInfo))) {
				_fileFormat = [[NSString stringWithUTF8String:formatInfo.name] retain];
			}
			else {
				_fileFormat = NSLocalizedStringFromTable(@"Unknown (libsndfile)", @"General", @"");
			}
		}
		
		@catch(NSException *exception) {
			@throw;
		}
	
		@finally {
			if(0 != sf_close(sndfile)) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the input file", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:sf_error(NULL)], [NSString stringWithUTF8String:sf_strerror(NULL)], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
			}
		}

		return self;
	}
	return nil;
}

- (NSString *)		inputFormat									{ return _fileFormat; }

@end
