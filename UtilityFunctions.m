/*
 *  $Id: UtilityFunctions.m 203 2005-12-04 22:20:50Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
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

static NSDateFormatter		*sDateFormatter		= nil;
static NSString				*sDataDirectory		= nil;

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
//					NSError *error = [NSError errorWithDomain:@"Initialization" code:0 userInfo:nil];
//					[[NSDocumentController sharedDocumentController] presentError:error];
					@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
				}
			}
			else if(NO == isDir) {
//				NSError *error = [NSError errorWithDomain:@"Initialization" code:0 userInfo:nil];
//				[[NSDocumentController sharedDocumentController] presentError:error];
				@throw [IOException exceptionWithReason:@"Unable to create application data directory" userInfo:nil];
			}
		}
	}
	return [[sDataDirectory retain] autorelease];
}

NSString *
basenameForMetadata(AudioMetadata *metadata)
{
	NSString		*basename;
	NSString		*outputDirectory;
	
	
	// Create output directory (should exist but could have been deleted/moved)
	outputDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:@"outputDirectory"] stringByExpandingTildeInPath];
	
	// Use custom naming scheme
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomNaming"]) {
		
		NSMutableString		*customPath			= [NSMutableString stringWithCapacity:100];
		NSString			*customNamingScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"customNamingScheme"];
		
		// Get the elements needed to build the pathname
		NSNumber			*discNumber			= [metadata valueForKey:@"discNumber"];
		NSNumber			*discsInSet			= [metadata valueForKey:@"discsInSet"];
		NSString			*discArtist			= [metadata valueForKey:@"albumArtist"];
		NSString			*discTitle			= [metadata valueForKey:@"albumTitle"];
		NSString			*discGenre			= [metadata valueForKey:@"albumGenre"];
		NSNumber			*discYear			= [metadata valueForKey:@"albumYear"];
		NSNumber			*trackNumber		= [metadata valueForKey:@"trackNumber"];
		NSString			*trackArtist		= [metadata valueForKey:@"trackArtist"];
		NSString			*trackTitle			= [metadata valueForKey:@"trackTitle"];
		NSString			*trackGenre			= [metadata valueForKey:@"trackGenre"];
		NSNumber			*trackYear			= [metadata valueForKey:@"trackYear"];
		
		// Fallback to disc if specified in preferences
		if([[NSUserDefaults standardUserDefaults] boolForKey:@"customNamingUseFallback"]) {
			if(nil == trackArtist) {
				trackArtist = discArtist;
			}
			if(nil == trackGenre) {
				trackGenre = discGenre;
			}
			if(nil == trackYear) {
				trackYear = discYear;
			}
		}
		
		if(nil == customNamingScheme) {
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Invalid custom naming string." userInfo:nil];
		}
		else {
			[customPath setString:customNamingScheme];
		}
		
		if(nil == discNumber) {
			[customPath replaceOccurrencesOfString:@"{discNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discNumber}" withString:[discNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];					
		}
		if(nil == discsInSet) {
			[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discsInSet}" withString:[discsInSet stringValue] options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discArtist) {
			[customPath replaceOccurrencesOfString:@"{discArtist}" withString:@"Unknown Artist" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discArtist}" withString:makeStringSafeForFilename(discArtist) options:nil range:NSMakeRange(0, [customPath length])];					
		}
		if(nil == discTitle) {
			[customPath replaceOccurrencesOfString:@"{discTitle}" withString:@"Unknown Disc" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discTitle}" withString:makeStringSafeForFilename(discTitle) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discGenre) {
			[customPath replaceOccurrencesOfString:@"{discGenre}" withString:@"Unknown Genre" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discGenre}" withString:makeStringSafeForFilename(discGenre) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == discYear) {
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{discYear}" withString:[discYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackNumber) {
			[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:@"" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			if([[NSUserDefaults standardUserDefaults] boolForKey:@"customNamingUseTwoDigitTrackNumbers"]) {
				[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[NSString stringWithFormat:@"%02u", [trackNumber intValue]] options:nil range:NSMakeRange(0, [customPath length])];
			}
			else {
				[customPath replaceOccurrencesOfString:@"{trackNumber}" withString:[trackNumber stringValue] options:nil range:NSMakeRange(0, [customPath length])];
			}
		}
		if(nil == trackArtist) {
			[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:@"Unknown Artist" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackArtist}" withString:makeStringSafeForFilename(trackArtist) options:nil range:NSMakeRange(0, [customPath length])];
		}
		if(nil == trackTitle) {
			[customPath replaceOccurrencesOfString:@"{trackTitle}" withString:@"Unknown Track" options:nil range:NSMakeRange(0, [customPath length])];
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
		if(nil == trackYear) {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:@"Unknown Year" options:nil range:NSMakeRange(0, [customPath length])];
		}
		else {
			[customPath replaceOccurrencesOfString:@"{trackYear}" withString:[trackYear stringValue] options:nil range:NSMakeRange(0, [customPath length])];
		}
		
		basename = [NSString stringWithFormat:@"%@/%@", outputDirectory, customPath];
	}
	// Use standard iTunes-style naming for compilations: "Compilations/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else if([[metadata valueForKey:@"multipleArtists"] boolValue]) {
		NSString			*path;
		
		NSString			*discTitle			= [metadata valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [metadata valueForKey:@"trackTitle"];
		
		if(nil == discTitle) {
			discTitle = @"Unknown Album";
		}
		if(nil == trackTitle) {
			trackTitle = @"Unknown Track";
		}
		
		path = [NSString stringWithFormat:@"%@/Compilations/%@", outputDirectory, makeStringSafeForFilename(discTitle)]; 
		
		if(nil == [metadata valueForKey:@"discNumber"]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
			basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[metadata valueForKey:@"discNumber"] intValue], [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
	}
	// Use standard iTunes-style naming: "Artist/Album/DiscNumber-TrackNumber TrackTitle.mp3"
	else {
		NSString			*path;
		
		NSString			*discArtist			= [metadata valueForKey:@"albumArtist"];
		NSString			*trackArtist		= [metadata valueForKey:@"trackArtist"];
		NSString			*artist;
		NSString			*discTitle			= [metadata valueForKey:@"albumTitle"];
		NSString			*trackTitle			= [metadata valueForKey:@"trackTitle"];
		
		artist = trackArtist;
		if(nil == artist) {
			artist = discArtist;
			if(nil == artist) {
				artist = @"Unknown Artist";
			}
		}
		if(nil == discTitle) {
			discTitle = @"Unknown Album";
		}
		if(nil == trackTitle) {
			trackTitle = @"Unknown Track";
		}
		
		path = [NSString stringWithFormat:@"%@/%@/%@", outputDirectory, makeStringSafeForFilename(artist), makeStringSafeForFilename(discTitle)]; 
		
		if(nil == [metadata valueForKey:@"discNumber"]) {
			basename = [NSString stringWithFormat:@"%@/%02u %@", path, [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
		else {
					basename = [NSString stringWithFormat:@"%@/%i-%02u %@", path, [[metadata valueForKey:@"discNumber"] intValue], [[metadata valueForKey:@"trackNumber"] unsignedIntValue], makeStringSafeForFilename(trackTitle)];
		}
	}
	
	return [[basename retain] autorelease];
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
			@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Unable to create directory" userInfo:nil];
		}
	}
	else if(FALSE == isDir) {
		@throw [NSException exceptionWithName:@"NSObjectInaccessibleException" reason:@"Unable to create directory" userInfo:nil];
	}	
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
	NSBeep();
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle: @"OK"];
	if([exception isKindOfClass:[FreeDBException class]]) {
		[alert setMessageText: @"FreeDB Error"];
	}
	else if([exception isKindOfClass:[IOException class]]) {
		[alert setMessageText: @"Input/Output Error"];
	}
	else if([exception isKindOfClass:[MallocException class]]) {
		[alert setMessageText: @"Memory Error"];
	}
	else if([exception isKindOfClass:[LAMEException class]]) {
		[alert setMessageText: @"LAME Error"];
	}
	else if([exception isKindOfClass:[EmptySelectionException class]]) {
		[alert setMessageText: @"Empty Selection"];
	}
	else if([exception isKindOfClass:[CustomNamingException class]]) {
		[alert setMessageText: @"Custom Naming Error"];
	}
	else if([exception isKindOfClass:[MissingResourceException class]]) {
		[alert setMessageText: @"Missing Resource"];
	}
	else if([exception isKindOfClass:[ParanoiaException class]]) {
		[alert setMessageText: @"cdparanoia Error"];
	}
	else if([exception isKindOfClass:[FLACException class]]) {
		[alert setMessageText: @"FLAC Error"];
	}
	else if([exception isKindOfClass:[VorbisException class]]) {
		[alert setMessageText: @"Ogg Vorbis Error"];
	}
	else {
		[alert setMessageText: @"Unknown Error"];
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
