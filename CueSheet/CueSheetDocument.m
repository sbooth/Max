/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
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

#import "CueSheetDocument.h"

#include <cuetools/cd.h>
#include <cuetools/cue.h>

@implementation CueSheetDocument

- (id) init
{
	if((self = [super init])) {

		_tracks		= [[NSMutableArray alloc] init];
		
		return self;
	}
	return nil;
}

- (void) dealloc
{
	[_MCN release];				_MCN = nil;

	[_title release];			_title = nil;
	[_performer release];		_performer = nil;
	[_songwriter release];		_songwriter = nil;
	[_composer release];		_composer = nil;
	[_arranger release];		_arranger = nil;
	[_UPC release];				_UPC = nil;
	
	[_tracks release];			_tracks = nil;
	
	[super dealloc];
}

- (NSString *)				windowNibName { return @"CueSheetDocument"; }

- (BOOL) writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if([typeName isEqualToString:@"CD Cue Sheet"]) {
		return YES;
	}
	return NO;
}

- (BOOL) readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if([typeName isEqualToString:@"CD Cue Sheet"] && [absoluteURL isFileURL]) {
		FILE		*f				= NULL;
		Cd			*cd				= NULL;
		Cdtext		*cdtext			= NULL;
		int			i;
		
		
		f = fopen([[absoluteURL path] fileSystemRepresentation], "r");
		if(NULL == f) {
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") forKey:NSLocalizedFailureReasonErrorKey]];
			return NO;
		}
		
		cd = cue_parse(f);
		if(NULL == cd) {
			fclose(f);
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:[NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Unable to open the input file.", @"Exceptions", @"") forKey:NSLocalizedFailureReasonErrorKey]];
			return NO;
		}
		
		[self setMode:cd_get_mode(cd)];
		
		if(NULL != cd_get_catalog(cd)) {
			[self setMCN:[NSString stringWithCString:cd_get_catalog(cd) encoding:NSASCIIStringEncoding]];
		}
		
		cdtext = cd_get_cdtext(cd);
		if(NULL != cdtext) {
			char *value;
			
			value = cdtext_get(PTI_TITLE, cdtext);
			if(NULL != value) {
				[self setTitle:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}
			value = cdtext_get(PTI_PERFORMER, cdtext);
			if(NULL != value) {
				[self setPerformer:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}
			value = cdtext_get(PTI_SONGWRITER, cdtext);
			if(NULL != value) {
				[self setSongwriter:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}
			value = cdtext_get(PTI_COMPOSER, cdtext);
			if(NULL != value) {
				[self setComposer:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}
			value = cdtext_get(PTI_ARRANGER, cdtext);
			if(NULL != value) {
				[self setArranger:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}
			value = cdtext_get(PTI_UPC_ISRC, cdtext);
			if(NULL != value) {
				[self setUPC:[NSString stringWithCString:value encoding:NSASCIIStringEncoding]];
			}
		}
		
		// Parse each track
		[self willChangeValueForKey:@"tracks"];
		for(i = 1; i <= cd_get_ntrack(cd); ++i) {
			struct Track			*track;
			NSMutableDictionary		*dictionary;
			
			track = cd_get_track(cd, i);
			
			dictionary = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:i], nil]
															forKeys:[NSArray arrayWithObjects:@"trackNumber", nil]];
			
			cdtext = track_get_cdtext(track);
			if(NULL != cdtext) {
				char *value;
				
				value = cdtext_get(PTI_TITLE, cdtext);
				if(NULL != value) {
					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"title"];
				}
				value = cdtext_get(PTI_PERFORMER, cdtext);
				if(NULL != value) {
					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"performer"];
				}
				value = cdtext_get(PTI_SONGWRITER, cdtext);
				if(NULL != value) {
					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"songwriter"];
				}
				value = cdtext_get(PTI_COMPOSER, cdtext);
				if(NULL != value) {
					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"composer"];
				}
				value = cdtext_get(PTI_ARRANGER, cdtext);
				if(NULL != value) {
					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"arranger"];
				}
				value = cdtext_get(PTI_UPC_ISRC, cdtext);
				if(NULL != value) {
					[dictionary setObject:[NSString stringWithCString:value encoding:NSASCIIStringEncoding] forKey:@"ISRC"];
				}
			}

			[self insertObject:dictionary inTracksAtIndex:i - 1];
		}
		[self didChangeValueForKey:@"tracks"];
				
		cd_delete(cd);
		fclose(f);

		return YES;
	}
    return NO;
}

#pragma mark Accessors

- (int)				mode								{ return _mode; }
- (NSString *)		MCN									{ return [[_MCN retain] autorelease]; }
- (NSString *)		title								{ return [[_title retain] autorelease]; }
- (NSString *)		performer							{ return [[_performer retain] autorelease]; }
- (NSString *)		songwriter							{ return [[_songwriter retain] autorelease]; }
- (NSString *)		composer							{ return [[_composer retain] autorelease]; }
- (NSString *)		arranger							{ return [[_arranger retain] autorelease]; }
- (NSString *)		UPC									{ return [[_UPC retain] autorelease]; }

- (unsigned)		countOfTracks						{ return [_tracks count]; }
- (id)				objectInTracksAtIndex:(unsigned)index { return [_tracks objectAtIndex:index]; }

#pragma mark Mutators

- (void) setMode:(int)mode								{ _mode = mode; }
- (void) setMCN:(NSString *)MCN							{ [_MCN release]; _MCN = [MCN retain]; }
- (void) setTitle:(NSString *)title						{ [_title release]; _title = [title retain]; }
- (void) setPerformer:(NSString *)performer				{ [_performer release]; _performer = [performer retain]; }
- (void) setSongwriter:(NSString *)songwriter			{ [_songwriter release]; _songwriter = [songwriter retain]; }
- (void) setComposer:(NSString *)composer				{ [_composer release]; _composer = [composer retain]; }
- (void) setArranger:(NSString *)arranger				{ [_arranger release]; _arranger = [arranger retain]; }
- (void) setUPC:(NSString *)UPC							{ [_UPC release]; _UPC = [UPC retain]; }

- (void) insertObject:(id)track inTracksAtIndex:(unsigned)index			{ [_tracks insertObject:track atIndex:index]; }
- (void) removeObjectFromTracksAtIndex:(unsigned)index					{ [_tracks removeObjectAtIndex:index]; }

@end
