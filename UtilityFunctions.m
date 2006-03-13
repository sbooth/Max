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

#import "UtilityFunctions.h"

#import "FreeDBException.h"
#import "MallocException.h"
#import "IOException.h"
#import "LAMEException.h"
#import "EmptySelectionException.h"
#import "CustomNamingException.h"
#import "MissingResourceException.h"
#import "ParanoiaException.h"
#import "FLACException.h"
#import "VorbisException.h"
#import "FileFormatNotSupportedException.h"
#import "CoreAudioException.h"
#import "SpeexException.h"

#include <sndfile/sndfile.h>

static NSDateFormatter		*sDateFormatter		= nil;
static NSString				*sDataDirectory		= nil;
static NSArray				*sAudioExtensions	= nil;
static NSArray				*sBuiltinExtensions	= nil;

NSString *
getApplicationDataDirectory()
{
	@synchronized(sDataDirectory) {
		if(nil == sDataDirectory) {
			BOOL					isDir;
			NSFileManager			*manager;
			NSArray					*paths;
			
			manager			= [NSFileManager defaultManager];
			paths			= NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
			sDataDirectory	= [[[paths objectAtIndex:0] stringByAppendingString:@"/Max"] retain];

			if(NO == [manager fileExistsAtPath:sDataDirectory isDirectory:&isDir]) {
				if(NO == [manager createDirectoryAtPath:sDataDirectory attributes:nil]) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create application data directory", @"Exceptions", @"") userInfo:nil];
				}
			}
			else if(NO == isDir) {
				@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to create application data directory", @"Exceptions", @"") userInfo:nil];
			}
		}
	}
	return [[sDataDirectory retain] autorelease];
}

void 
createDirectoryStructure(NSString *path)
{
	NSString		*pathPart;
	NSArray			*pathComponents		= [path pathComponents];
	
	if(1 < [pathComponents count]) {
		int				i;
		int				directoryCount		= [pathComponents count] - 1;

		// Accept a '/' as the first path
		if(NO == [[pathComponents objectAtIndex:0] isEqualToString:@"/"]) {
			pathPart = makeStringSafeForFilename([pathComponents objectAtIndex:0]);
		}
		else {
			pathPart = [pathComponents objectAtIndex:0];
		}		
		validateAndCreateDirectory(pathPart);
		
		// Iterate through all the components
		for(i = 1; i < directoryCount - 1; ++i) {
			pathPart = [NSString stringWithFormat:@"%@/%@", pathPart, makeStringSafeForFilename([pathComponents objectAtIndex:i])];				
			validateAndCreateDirectory(pathPart);
		}
		
		// Ignore trailing '/'
		if(NO == [[pathComponents objectAtIndex:directoryCount - 1] isEqualToString:@"/"]) {
			pathPart = [NSString stringWithFormat:@"%@/%@", pathPart, makeStringSafeForFilename([pathComponents objectAtIndex:directoryCount - 1])];
			validateAndCreateDirectory(pathPart);
		}
	}
}

NSString * 
makeStringSafeForFilename(NSString *string)
{
	NSCharacterSet		*characterSet		= [NSCharacterSet characterSetWithCharactersInString:@"/:"];
	NSMutableString		*result				= [NSMutableString stringWithCapacity:[string length]];
	NSRange				range;
	
	[result setString:string];
	
	range = [result rangeOfCharacterFromSet:characterSet];		
	while(range.location != NSNotFound && range.length != 0) {
		[result replaceCharactersInRange:range withString:@"_"];
		range = [result rangeOfCharacterFromSet:characterSet];		
	}
	
	return [[result retain] autorelease];
}

NSString * 
generateUniqueFilename(NSString *basename, NSString *extension)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	unsigned			num					= 1;
	NSString			*result;
	
	result = [NSString stringWithFormat:@"%@.%@", basename, extension];
	for(;;) {
		if(NO == [manager fileExistsAtPath:result]) {
			break;
		}
		result = [NSString stringWithFormat:@"%@-%u.%@", basename, num, extension];
		++num;
	}
	
	return [[result retain] autorelease];
}

void
validateAndCreateDirectory(NSString *path)
{
	NSFileManager		*manager			= [NSFileManager defaultManager];
	BOOL				isDir;

	if(NO == [manager fileExistsAtPath:path isDirectory:&isDir]) {
		if(NO == [manager createDirectoryAtPath:path attributes:nil]) {
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:NSLocalizedStringFromTable(@"Unable to create directory", @"Exceptions", @"")
										 userInfo:[NSDictionary dictionaryWithObject:path forKey:@"pathname"]];
		}
	}
	else if(NO == isDir) {
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:NSLocalizedStringFromTable(@"Unable to create directory", @"Exceptions", @"")
									 userInfo:[NSDictionary dictionaryWithObject:path forKey:@"pathname"]];
	}	
}

NSArray * 
getBuiltinExtensions()
{
	@synchronized(sBuiltinExtensions) {
		if(nil == sBuiltinExtensions) {
			sBuiltinExtensions = [NSArray arrayWithObjects:@"ogg", @"flac", @"oggflac", @"spx", nil];
			[sBuiltinExtensions retain];
		}
	}
	
	return sBuiltinExtensions;
}

NSArray *
getLibsndfileExtensions()
{
	SF_FORMAT_INFO			formatInfo;
	SF_INFO					info;
	int						i, majorCount = 0;

	@synchronized(sAudioExtensions) {
		if(nil == sAudioExtensions) {

			sf_command(NULL, SFC_GET_FORMAT_MAJOR_COUNT, &majorCount, sizeof(int)) ;

			sAudioExtensions = [NSMutableArray arrayWithCapacity:majorCount];
			
			// Generic defaults
			info.channels		= 1 ;
			info.samplerate		= 0;
			
			// Loop through each major mode
			for(i = 0; i < majorCount; ++i) {	
				formatInfo.format = i;
				sf_command(NULL, SFC_GET_FORMAT_MAJOR, &formatInfo, sizeof(formatInfo));
				[(NSMutableArray *)sAudioExtensions addObject:[NSString stringWithUTF8String:formatInfo.extension]];
			}
			
			[sAudioExtensions retain];
		}
	}
	
	return sAudioExtensions;
}

void
displayExceptionAlert(NSException *exception)
{
	displayExceptionSheet(exception, nil, nil, nil, nil);
}

void 
displayExceptionSheet(NSException	*exception,
					  NSWindow		*window,
					  id			delegate,
					  SEL			selector,
					  void			*contextInfo)
{
	NSLog(@"Exception: %@ (userInfo = %@)", exception, [exception userInfo]);
	
	NSBeep();
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle: NSLocalizedStringFromTable(@"OK", @"General", @"")];
	if([exception isKindOfClass:[FreeDBException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"FreeDB Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[IOException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Input/Output Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[MallocException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Memory Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[LAMEException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"LAME Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[EmptySelectionException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Empty Selection", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[CustomNamingException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Custom Naming Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[MissingResourceException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Missing Resource", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[ParanoiaException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"cdparanoia Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[FLACException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"FLAC Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[VorbisException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Ogg Vorbis Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[FileFormatNotSupportedException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"File Format Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[CoreAudioException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Core Audio Error", @"Exceptions", @"")];
	}
	else if([exception isKindOfClass:[SpeexException class]]) {
		[alert setMessageText: NSLocalizedStringFromTable(@"Speex Error", @"Exceptions", @"")];
	}
	else {
		Debugger();
		[alert setMessageText: NSLocalizedStringFromTable(@"Unknown Error", @"Exceptions", @"")];
	}
	[alert setInformativeText: [exception reason]];
	[alert setAlertStyle: NSWarningAlertStyle];
	
	if(nil == window) {
		if([alert runModal] == NSAlertFirstButtonReturn) {
			// do nothing
		} 
	}
	else {
		[alert beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:selector contextInfo:contextInfo];
	}
}

NSString *
getID3v2Timestamp()
{
	@synchronized(sDateFormatter) {
		if(nil == sDateFormatter) {
			[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
			sDateFormatter = [[NSDateFormatter alloc] init];
			[sDateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
			[sDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
		}
	}
	return [sDateFormatter stringFromDate:[NSDate date]];
}

void
addVorbisComment(FLAC__StreamMetadata		*block,
				 NSString					*key,
				 NSString					*value)
{
	NSString									*string;
	FLAC__StreamMetadata_VorbisComment_Entry	entry;
	
	string			= [NSString stringWithFormat:@"%@=%@", key, value];
	entry.length	= [string length];
	entry.entry		= NULL;
	entry.entry		= (unsigned char *)strdup([string UTF8String]);
	if(NULL == entry.entry) {
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") userInfo:nil];
	}
	
	if(NO == FLAC__metadata_object_vorbiscomment_append_comment(block, entry, NO)) {
		free(entry.entry);
		@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory", @"Exceptions", @"") userInfo:nil];
	}	
}

NSData *
getPNGDataForImage(NSImage *image)
{
	NSEnumerator		*enumerator					= nil;
	NSImageRep			*currentRepresentation		= nil;
	NSBitmapImageRep	*bitmapRep					= nil;
	NSSize				size;
	
	if(nil == image) {
		return nil;
	}
	
	enumerator = [[image representations] objectEnumerator];
	while((currentRepresentation = [enumerator nextObject])) {
		if([currentRepresentation isKindOfClass:[NSBitmapImageRep class]]) {
			bitmapRep = (NSBitmapImageRep *)currentRepresentation;
		}
	}
	
	// Create a bitmap representation if one doesn't exist
	if(nil == bitmapRep) {
		size = [image size];
		[image lockFocus];
		bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, size.width, size.height)] autorelease];
		[image unlockFocus];
	}
	
	return [bitmapRep representationUsingType:NSPNGFileType properties:nil]; 
}

BOOL
outputFormatsSelected()
{
	BOOL		outputLibsndfile	= (0 != [[[NSUserDefaults standardUserDefaults] objectForKey:@"libsndfileOutputFormats"] count]);
	BOOL		outputCoreAudio		= (0 != [[[NSUserDefaults standardUserDefaults] objectForKey:@"coreAudioOutputFormats"] count]);
	BOOL		outputMP3			= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputMP3"];
	BOOL		outputFLAC			= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputFLAC"];
	BOOL		outputOggFLAC		= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggFLAC"];
	BOOL		outputOggVorbis		= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputOggVorbis"];
	BOOL		outputSpeex			= [[NSUserDefaults standardUserDefaults] boolForKey:@"outputSpeex"];
	
	return (outputLibsndfile || outputCoreAudio || outputMP3 || outputFLAC || outputOggFLAC || outputOggVorbis || outputSpeex);
}
