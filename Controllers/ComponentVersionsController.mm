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

#import "ComponentVersionsController.h"

#include <lame/lame.h>
#include <FLAC/format.h>
#include <speex/speex.h>
#include <sndfile/sndfile.h>
#include <mac/All.h>
#include <wavpack/wavpack.h>

#include <wchar.h>

@implementation NSString (WideCharSupport)

+ (NSString *) stringWithWideString:(const wchar_t *)ws
{
	size_t buflen = 8 * wcslen(ws) + 1;
	char *temp = (char *)malloc(buflen);
	wcstombs(temp, ws, buflen);
	NSString* retVal = [self stringWithUTF8String:temp];
	free(temp);
	return retVal;
}

@end

static ComponentVersionsController *sharedController = nil;

@implementation ComponentVersionsController

+ (ComponentVersionsController *) sharedController
{
	@synchronized(self) {
		if(nil == sharedController)
			[[self alloc] init];
	}
	return sharedController;
}

+ (id) allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if(nil == sharedController) {
            sharedController = [super allocWithZone:zone];
			return sharedController;
        }
    }
    return nil;
}

- (id)init
{
	if((self = [super initWithWindowNibName:@"ComponentVersions"])) {

		const char		*speexVersion;
		char			buffer [128];
		
		speex_lib_ctl(SPEEX_LIB_GET_VERSION_STRING, &speexVersion);
		sf_command(NULL, SFC_GET_LIB_VERSION, buffer, sizeof(buffer));
		
		_flacVersion		= [NSString stringWithFormat:@"FLAC %s", FLAC__VERSION_STRING];
		_lameVersion		= [NSString stringWithFormat:@"LAME %s", get_lame_version()];
		_macVersion			= [NSString stringWithFormat:@"Monkey's Audio %@", [NSString stringWithWideString:MAC_VERSION_STRING]];

		if(NULL != speexVersion) {
			_speexVersion		= [NSString stringWithCString:speexVersion encoding:NSASCIIStringEncoding];
		}
		else {
			_speexVersion		= NSLocalizedStringFromTable(@"Unknown", @"General", @"");
		}

		_libsndfileVersion	= [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];

		_wavPackVersion		= [NSString stringWithFormat:@"WavPack %s", WavpackGetLibraryVersionString()];
		
		return self;
	}
	return nil;
}

- (void) windowDidLoad
{
	[self setShouldCascadeWindows:NO];
	[[self window] center];
}

- (id)			copyWithZone:(NSZone *)zone						{ return self; }
- (id)			retain											{ return self; }
- (NSUInteger)	retainCount										{ return UINT_MAX;  /* denotes an object that cannot be released */ }
- (oneway void)	release											{ /* do nothing */ }
- (id)			autorelease										{ return self; }

@end
