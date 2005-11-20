/*
 *  $Id$
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

#import "CompactDisc.h"
#import "Track.h"
#import "MallocException.h"
#import "IOException.h"

#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/storage/IOCDMedia.h>
#include <IOKit/storage/IOCDTypes.h>

#include <CoreFoundation/CoreFoundation.h>

#include <sys/param.h>		// MAXPATHLEN
#include <paths.h>			//_PATH_DEV

// ==================================================
// Code from the CDDB howto
// ==================================================
static int
cddb_sum(int n)
{
	int ret = 0;
	
	while(0 < n) {
		ret = ret + (n % 10);
		n = n / 10;
	}
	
	return ret;
}
// ==================================================
// End CDDB code
// ==================================================

@implementation CompactDisc

+ (CompactDisc *) createFromIOObject:(io_object_t)disc
{
	CDTOC					*toc;
	NSMutableDictionary		*properties;
	NSData					*data;
	
	kern_return_t			err					= KERN_FAILURE;
	
	unsigned				i;
	UInt32					numDescriptors;
	
	char					bsdPath [MAXPATHLEN];
	NSString				*path;
	CFTypeRef				deviceName;
	
	CompactDisc				*result;
	
	
	@try {
		// Grab a dictionary containing all the properties of the CD
		err = IORegistryEntryCreateCFProperties(disc, (CFMutableDictionaryRef *)&properties, kCFAllocatorDefault, kNilOptions);
		if(KERN_SUCCESS != err) {
			@throw [IOException exceptionWithReason:@"Unable to access IORegistry" userInfo:nil];
		}
		
		// Extract the CD's TOC data
		data = [properties objectForKey: [NSString stringWithCString: kIOCDMediaTOCKey]];
		toc = (CDTOC *) [data bytes];
		
		result = [[[CompactDisc alloc] init] autorelease];
		[result setValue:[NSNumber numberWithInt:disc] forKey:@"io_object"];
		[result setValue: [properties objectForKey: [NSString stringWithCString:kIOMediaPreferredBlockSizeKey]] forKey: @"preferredBlockSize"];
		
		// Loop over each descriptor in the TOC
		numDescriptors = CDTOCGetDescriptorCount(toc);
		for(i = 0; i < numDescriptors; ++i) {
			CDTOCDescriptor *desc = &toc->descriptors[i];
			
			// A disc can have up to 99 tracks
			if(99 >= desc->point && 1 == desc->adr) {
				Track *track = [[Track alloc] init];
				[track setValue:result forKey:@"disc"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->point] forKey:@"number"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->p.minute] forKey:@"minute"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->p.second] forKey:@"second"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->p.frame] forKey:@"frame"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->control] forKey:@"type"];
				[result addTrack: track];
			}
			
			// 0xA0 identifies the first track and disc type
			else if(0xA0 == desc->point && 1 == desc->adr) {
				[result setValue:[NSNumber numberWithUnsignedInt:desc->p.second] forKey:@"type"];
				[result setValue:[NSNumber numberWithUnsignedInt:desc->p.minute] forKey:@"firstTrack"];
			}
			
			// 0xA1 identifies the last track
			else if(0xA1 == desc->point && 1 == desc->adr) {
				[result setValue:[NSNumber numberWithUnsignedInt:desc->p.minute] forKey:@"lastTrack"];
			}
			
			// 0xA2 identifies the lead-out
			else if(0xA2 == desc->point && 1 == desc->adr) {
				Track *track = [[Track alloc] init];
				[track setValue:result forKey:@"disc"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->point] forKey:@"number"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->p.minute] forKey:@"minute"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->p.second] forKey:@"second"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->p.frame] forKey:@"frame"];
				[track setValue:[NSNumber numberWithUnsignedInt:desc->control] forKey:@"type"];
				[result setValue:track forKey:@"leadOut"];
			}
		}	
		
		// Fill in last sector information
		unsigned lastTrack = [[result valueForKey:@"lastTrack"] unsignedIntValue];
		for(i = 1; i < lastTrack; ++i) {
			Track *track			= [[result valueForKey:@"tracks"] objectAtIndex:i];
			Track *previousTrack	= [[result valueForKey:@"tracks"] objectAtIndex:i - 1];
			[previousTrack setValue:[NSNumber numberWithUnsignedInt:([[track getFirstSector] unsignedIntValue] - 1)] forKey:@"lastSector"];
		}
		Track *track			= [result valueForKey:@"leadOut"];
		Track *previousTrack	= [[result valueForKey:@"tracks"] objectAtIndex:lastTrack - 1];
		[previousTrack setValue:[NSNumber numberWithInt:([[track getFirstSector] unsignedIntValue] - 1)] forKey:@"lastSector"];	
		
		// Get the BSD path for the device
		deviceName = IORegistryEntryCreateCFProperty(disc, CFSTR(kIOBSDNameKey), kCFAllocatorDefault, 0);
		if(NULL == deviceName) {
			@throw [IOException exceptionWithReason:@"Unable to create BSD path for device" userInfo:nil];
		}
		path = [[NSString stringWithCString: _PATH_DEV] stringByAppendingString:@"r"];
		if(FALSE ==  CFStringGetCString(deviceName, bsdPath, MAXPATHLEN, kCFStringEncodingASCII)) {
			// What's the best kind of exception to raise here?
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		path = [path stringByAppendingString: [NSString stringWithCString:bsdPath]];
		[result setValue:path forKey:@"bsdPath"];
	}
	
	@catch(NSException *exception) {
		@throw;
	}
	
	@finally {
		CFRelease(deviceName);
	}

	return result;
}

- (id)init
{
	if((self = [super init])) {
		_tracks = [[NSMutableArray alloc] initWithCapacity:20];
	}
	
	return self;
}

- (void) dealloc
{
	[_tracks release];
	
	[super dealloc];
}

- (unsigned long) cddb_id
{
	int		i				= 0;
	int		t				= 0;
	int		n				= 0;
	int		total_tracks	= [_tracks count];
	Track	*track			= nil;
	
	while(i < total_tracks) {
		track = [_tracks objectAtIndex: i];
		n += cddb_sum(([[track valueForKey:@"minute"] intValue] * 60) + [[track valueForKey:@"second"] intValue]);
		i++;
	}
	
	track = [_tracks objectAtIndex: 0];
	t = (([[_leadOut valueForKey:@"minute"] intValue] * 60) + [[_leadOut valueForKey:@"second"] intValue]) - 
		(([[track valueForKey:@"minute"] intValue] * 60) + [[track valueForKey:@"second"] intValue]);
	
	return ((n % 0xff) << 24 | t << 8 | total_tracks);	
}

- (NSNumber *) getDuration
{
	int					i;
	unsigned int		result = 0;
	int					totalTracks	= [_tracks count];
	
	for(i = 0; i < totalTracks; ++i) {
		result += [[[_tracks objectAtIndex:i] getDuration] unsignedIntValue];
	}
	
	return [NSNumber numberWithUnsignedInt:result];
}

- (NSArray *) selectedTracks
{
	NSMutableArray	*result			= [[[NSMutableArray alloc] initWithCapacity:[_lastTrack intValue]] autorelease];
	NSEnumerator	*enumerator		= [_tracks objectEnumerator];
	Track			*track;
	
	while((track = [enumerator nextObject])) {
		if(YES == [[track valueForKey:@"selected"] boolValue]) {
			[result addObject: track];
		}
	}
	
	return result;
}

- (void) addTrack:(Track *)value					{ [_tracks addObject: value]; }
- (void) setLeadOut:(Track *)leadOut				{ [_leadOut release]; _leadOut = [leadOut retain]; }

#pragma mark Save/Restore

- (NSDictionary *) getDictionary
{
	unsigned				i;
	NSMutableDictionary		*result		= [[[NSMutableDictionary alloc] init] autorelease];
	NSMutableArray			*tracks		= [[[NSMutableArray alloc] initWithCapacity:[_tracks count]] autorelease];
		
	[result setValue:[self valueForKey:@"title"] forKey:@"title"];
	[result setValue:_artist forKey:@"artist"];
	[result setValue:_year forKey:@"year"];
	[result setValue:_genre forKey:@"genre"];
	[result setValue:_comment forKey:@"comment"];
	[result setValue:_discNumber forKey:@"discNumber"];
	[result setValue:_discsInSet forKey:@"discsInSet"];
	[result setValue:_multiArtist forKey:@"multiArtist"];
	
	for(i = 0; i < [_tracks count]; ++i) {
		[tracks addObject:[[_tracks objectAtIndex:i] getDictionary]];
	}
	
	[result setValue:tracks forKey:@"tracks"];
	
	return result;
}

- (void) setPropertiesFromDictionary:(NSDictionary *) properties
{
	unsigned				i;
	NSArray					*tracks			= [properties valueForKey:@"tracks"];
	
	if([tracks count] != [_tracks count]) {
		@throw [NSException exceptionWithName:@"NSInternalInconsistencyException" reason:@"Track count mismatch" userInfo:nil];
	}

	for(i = 0; i < [tracks count]; ++i) {
		[[_tracks objectAtIndex:i] setPropertiesFromDictionary:[tracks objectAtIndex:i]];
	}
	
	[self setValue:[properties valueForKey:@"title"] forKey:@"title"];
	[self setValue:[properties valueForKey:@"artist"] forKey:@"artist"];
	[self setValue:[properties valueForKey:@"year"] forKey:@"year"];
	[self setValue:[properties valueForKey:@"genre"] forKey:@"genre"];
	[self setValue:[properties valueForKey:@"comment"] forKey:@"comment"];
	[self setValue:[properties valueForKey:@"discNumber"] forKey:@"discNumber"];
	[self setValue:[properties valueForKey:@"discsInSet"] forKey:@"discsInSet"];
	[self setValue:[properties valueForKey:@"multiArtist"] forKey:@"multiArtist"];
}

@end
