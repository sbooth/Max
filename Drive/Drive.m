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

#import "Drive.h"

#include <IOKit/storage/IOCDMediaBSDClient.h>
#include <util.h> // opendev

#import "LogController.h"
#import "IOException.h"
#import "MallocException.h"

@interface Drive (Private)
- (void)				logMessage:(NSString *)message;
- (TrackDescriptor *)	objectInTracksAtIndex:(unsigned)index;

- (void)				setLeadOut:(unsigned)leadOut;
- (void)				setFirstTrack:(unsigned)firstTrack;
- (void)				setLastTrack:(unsigned)lastTrack;
- (void)				setFirstSession:(unsigned)session;
- (void)				setLastSession:(unsigned)session;

- (void)				readTOC;
- (int)					fileDescriptor;
@end

@implementation Drive

- (id) initWithDeviceName:(NSString *)deviceName
{
	if((self = [super init])) {
		
		_deviceName		= [deviceName retain];
		_fd				= -1;
		_cacheSize		= 2 * 1024 * 1024;
		
		_tracks			= [[NSMutableArray alloc] initWithCapacity:20];

		_leadOut		= 0;
		_firstSession	= 0;
		_lastSession	= 0;
		_firstTrack		= 0;
		_lastTrack		= 0;
		
		_fd				= opendev((char *)[[self deviceName] fileSystemRepresentation], O_RDONLY | O_NONBLOCK, 0, NULL);

		if(-1 == _fd) {
			@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to open the drive for reading.", @"Exceptions", @"")
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
				
		[self readTOC];
		
		return self;
	}
	
	return nil;
}

- (void)			dealloc
{
	if(-1 == close(_fd)) {
		NSException *exception;
		
		exception =  [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to close the drive.", @"Exceptions", @"")					
											 userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];

		[self logMessage:[exception description]];
	}
	
	_fd = -1;
	
	[_deviceName release];
	[_tracks release];
	[super dealloc];
}

- (unsigned)			cacheSize								{ return _cacheSize; }
- (unsigned)			cacheSectorSize							{ return (([self cacheSize] / kCDSectorSizeCDDA) + 1); }
- (void)				setCacheSize:(unsigned)cacheSize		{ _cacheSize = cacheSize; }

- (NSString *)			deviceName								{ return _deviceName; }
- (int)					fileDescriptor							{ return _fd; }

- (unsigned)			countOfTracks							{ return [_tracks count]; }
- (TrackDescriptor *)	objectInTracksAtIndex:(unsigned)idx		{ return [_tracks objectAtIndex:idx]; }

- (unsigned)			leadOut									{ return _leadOut; }
- (void)				setLeadOut:(unsigned)leadOut			{ _leadOut = leadOut; }

- (unsigned)			firstSession							{ return _firstSession; }
- (void)				setFirstSession:(unsigned)session		{ _firstSession = session; }

- (unsigned)			lastSession								{ return _lastSession; }
- (void)				setLastSession:(unsigned)session		{ _lastSession = session; }

- (unsigned)			firstSector								{ return [[self trackNumber:[self firstTrack]] firstSector]; }
- (unsigned)			lastSector								{ return [self leadOut] - 1; }

- (unsigned)			firstSectorForTrack:(unsigned)number	{ return [[self trackNumber:number] firstSector]; }
- (unsigned)			lastSectorForTrack:(unsigned)number
{
	TrackDescriptor		*track	= [self trackNumber:number + 1];
	
	return (nil == track ? [self lastSector] : [track firstSector] - 1);
}

- (unsigned)			firstTrack								{ return _firstTrack; }
- (void)				setFirstTrack:(unsigned)firstTrack		{ _firstTrack = firstTrack; }

- (unsigned)			lastTrack								{ return _lastTrack; }
- (void)				setLastTrack:(unsigned)lastTrack		{ _lastTrack = lastTrack; }

- (void)				logMessage:(NSString *)message
{
	[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:message waitUntilDone:NO];
}

- (TrackDescriptor *)		trackNumber:(unsigned)number
{
	TrackDescriptor		*track	= nil;
	unsigned			i;
	
	for(i = 0; i < [self countOfTracks]; ++i) {
		track = [self objectInTracksAtIndex:i];
		if([track number] == number) {
			return track;
		}
	}
	
	return nil;
}

- (uint16_t)		speed
{
	uint16_t	speed;
	
	speed = 0;
	
	if(-1 == ioctl([self fileDescriptor], DKIOCCDGETSPEED, &speed)) {
		[self logMessage:NSLocalizedStringFromTable(@"Unable to get the drive's speed", @"Exceptions", @"")];
		return 0;
	}
	
	return speed;
}

- (void)			setSpeed:(uint16_t)speed
{
	if(-1 == ioctl([self fileDescriptor], DKIOCCDSETSPEED, &speed)) {
		[self logMessage:NSLocalizedStringFromTable(@"Unable to set the drive's speed", @"Exceptions", @"")];
	}
}

- (void)			clearCache:(SectorRange *)range
{
	int16_t			*buffer											= NULL;
	unsigned		bufferLen										= 0;
	unsigned		requiredReadSize;
	unsigned		discFirstSector, discLastSector;
	unsigned		preSectorsAvailable, postSectorsAvailable;
	unsigned		sectorsRemaining, sectorsRead, boundary;
	
	requiredReadSize		= [self cacheSectorSize];
	discFirstSector			= [[self trackNumber:[self firstTrack]] firstSector];
	discLastSector			= [self leadOut] - 1;
	preSectorsAvailable		= [range firstSector] - discFirstSector;
	postSectorsAvailable	= discLastSector - [range lastSector];
	
	@try {
		// Allocate the buffer
		bufferLen	= requiredReadSize < 1024 ? requiredReadSize : 1024;
		buffer		= calloc(bufferLen, kCDSectorSizeCDDA);
		if(NULL == buffer) {
			@throw [MallocException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @"") 
											   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
		}
		
		// Make sure there are enough sectors outside the range to fill the cache
		if(preSectorsAvailable + postSectorsAvailable < requiredReadSize) {
			[self logMessage:NSLocalizedStringFromTable(@"Unable to flush the drive's cache", @"Exceptions", @"")];
			// What to do?
			return;
		}
		
		// Read from whichever block of sectors is the largest
		if(preSectorsAvailable > postSectorsAvailable && preSectorsAvailable >= requiredReadSize) {
			sectorsRemaining = requiredReadSize;
			while(0 < sectorsRemaining) {
				sectorsRead = [self readAudio:buffer
								  startSector:discFirstSector + (requiredReadSize - sectorsRemaining)
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				if(0 == sectorsRead) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @"") userInfo:nil];
				}
				sectorsRemaining -= sectorsRead;
			}
		}
		else if(postSectorsAvailable >= requiredReadSize) {
			sectorsRemaining = requiredReadSize;
			while(0 < sectorsRemaining) {
				sectorsRead = [self readAudio:buffer
								  startSector:discLastSector - sectorsRemaining
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				if(0 == sectorsRead) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @"") userInfo:nil];
				}
				sectorsRemaining -= sectorsRead;
			}
		}
		// Need to read multiple blocks
		else {
			
			// First read as much as possible from before the range
			boundary			= [range firstSector] - 1;
			sectorsRemaining	= boundary;
			
			while(0 < sectorsRemaining) {
				sectorsRead = [self readAudio:buffer
								  startSector:discFirstSector + (boundary - sectorsRemaining)
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				if(0 == sectorsRead) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @"") userInfo:nil];
				}
				sectorsRemaining -= sectorsRead;
			}
			
			// Read the remaining sectors from after the range
			boundary			= [range lastSector] + 1;
			sectorsRemaining	= requiredReadSize - sectorsRemaining;
			
			// This should never happen; we tested for it above
			if(sectorsRemaining > (discLastSector - boundary)) {
				NSLog(@"fnord!");
			}
			
			while(0 < sectorsRemaining) {
				sectorsRead = [self readAudio:buffer
								  startSector:discLastSector - sectorsRemaining
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				if(0 == sectorsRead) {
					@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @"") userInfo:nil];
				}
				sectorsRemaining -= sectorsRead;
			}
			
		}
	}
	
	@finally {
		free(buffer);
	}
}

- (void)			readTOC
{
	dk_cd_read_toc_t	cd_read_toc;
	uint8_t				buffer					[2048];
	CDTOC				*toc					= NULL;
	CDTOCDescriptor		*desc					= NULL;
	TrackDescriptor		*track					= nil;
	unsigned			i, numDescriptors;

	/* formats:
		kCDTOCFormatTOC  = 0x02, // CDTOC
		kCDTOCFormatPMA  = 0x03, // CDPMA
		kCDTOCFormatATIP = 0x04, // CDATIP
		kCDTOCFormatTEXT = 0x05  // CDTEXT
		*/
	
	bzero(&cd_read_toc, sizeof(cd_read_toc));
	bzero(buffer, sizeof(buffer));
	
	cd_read_toc.format			= kCDTOCFormatTOC;
	cd_read_toc.formatAsTime	= 1;
	cd_read_toc.address.track	= 0;
	cd_read_toc.buffer			= buffer;
	cd_read_toc.bufferLength	= sizeof(buffer);
		
	if(-1 == ioctl([self fileDescriptor], DKIOCCDREADTOC, &cd_read_toc)) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read the disc's table of contents.", @"Exceptions", @"")
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	toc				= (CDTOC*)buffer;
	numDescriptors	= CDTOCGetDescriptorCount(toc);
	
	[self setFirstSession:toc->sessionFirst];
	[self setLastSession:toc->sessionLast];
	
	for(i = 0; i < numDescriptors; ++i)
	{
		desc = &toc->descriptors[i];
		
		// This is a normal audio or data track
		if(0x63 >= desc->point && 1 == desc->adr) {
			track		= [[TrackDescriptor alloc] init];
			
			[track setSession:desc->session];
			[track setNumber:desc->point];
			[track setFirstSector:CDConvertMSFToLBA(desc->p)];
			
			switch(desc->control) {
				case 0x00:	[track setChannels:2];	[track setPreEmphasis:NO];	[track setCopyPermitted:NO];	break;
				case 0x01:	[track setChannels:2];	[track setPreEmphasis:YES];	[track setCopyPermitted:NO];	break;
				case 0x02:	[track setChannels:2];	[track setPreEmphasis:NO];	[track setCopyPermitted:YES];	break;
				case 0x03:	[track setChannels:2];	[track setPreEmphasis:YES];	[track setCopyPermitted:YES];	break;
				case 0x04:	[track setDataTrack:YES];							[track setCopyPermitted:NO];	break;
				case 0x06:	[track setDataTrack:YES];							[track setCopyPermitted:YES];	break;
				case 0x08:	[track setChannels:4];	[track setPreEmphasis:NO];	[track setCopyPermitted:NO];	break;
				case 0x09:	[track setChannels:4];	[track setPreEmphasis:YES];	[track setCopyPermitted:NO];	break;
				case 0x0A:	[track setChannels:4];	[track setPreEmphasis:NO];	[track setCopyPermitted:YES];	break;
				case 0x0B:	[track setChannels:4];	[track setPreEmphasis:NO];	[track setCopyPermitted:YES];	break;
			}
			
			[_tracks addObject:[track autorelease]];
		}
		else if(0xA0 == desc->point && 1 == desc->adr)
		{
			[self setFirstTrack:desc->p.minute];
			/*printf("Disc type:                 %d (%s)\n", (int)desc->p.second,
				   (desc->p.second == 0x00) ? "CD-DA, or CD-ROM with first track in Mode 1":
				   (desc->p.second == 0x10) ? "CD-I disc":
				   (desc->p.second == 0x20) ? "CD-ROM XA disc with first track in Mode 2":"unknown");*/
		}
		// Last track
		else if(0xA1 == desc->point && 1 == desc->adr)
		{
			[self setLastTrack:desc->p.minute];
		}
		// Lead-out
		else if(0xA2 == desc->point && 1 == desc->adr)
		{
			[self setLeadOut:CDConvertMSFToLBA(desc->p)];
		}
		/*else if(0xB0 == desc->point && 5 == desc->adr)
		{
			printf("Next possible track start: %02d:%02d.%02d\n",
				   (int)desc->address.minute, (int)desc->address.second, (int)desc->address.frame);
			printf("Number of ptrs in Mode 5:  %d\n",
				   (int)desc->zero);
			printf("Last possible lead-out:    %02d:%02d.%02d\n",
				   (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame);
		}
		else if(0xB1 == desc->point && 5 == desc->adr)
		{
			printf("Skip interval pointers:    %d\n", (int)desc->p.minute);
			printf("Skip track pointers:       %d\n", (int)desc->p.second);
		}
		else if(0xB2 <= desc->point && 0xB2 >= desc->point && 5 == desc->adr)
		{
			printf("Skip numbers:              %d, %d, %d, %d, %d, %d, %d\n",
				   (int)desc->address.minute, (int)desc->address.second, (int)desc->address.frame,
				   (int)desc->zero, (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame);
		}
		else if(1 == desc->point && 40 >= desc->point && 5 == desc->adr)
		{
			printf("Skip from %02d:%02d.%02d to %02d:%02d.%02d\n",
				   (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame,
				   (int)desc->address.minute, (int)desc->address.second, (int)desc->address.frame);
		}
		else if(0xC0 == desc->point && 5 == desc->adr)
		{
			printf("Optimum recording power:   %d\n", (int)desc->address.minute);
			printf("Application code:          %d\n", (int)desc->address.second);
			printf("Start of first lead-in:    %02d:%02d.%02d\n",
				   (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame);
		}*/
	}
}

- (unsigned)		readAudio:(void *)buffer sector:(unsigned)sector
{
	return [self readAudio:buffer startSector:sector sectorCount:1];
}

- (unsigned)		readAudio:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudio:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (unsigned)		readAudio:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	dk_cd_read_t	cd_read;
	
	bzero(&cd_read, sizeof(cd_read));
	bzero(buffer, kCDSectorSizeCDDA * sectorCount);
	
	cd_read.offset			= kCDSectorSizeCDDA * startSector;
	cd_read.sectorArea		= kCDSectorAreaUser;
	cd_read.sectorType		= kCDSectorTypeCDDA;
	cd_read.buffer			= buffer;
	cd_read.bufferLength	= kCDSectorSizeCDDA * sectorCount;
	
	if(-1 == ioctl([self fileDescriptor], DKIOCCDREAD, &cd_read)) {
		@throw [IOException exceptionWithReason:NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @"")
									   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];
	}
	
	return cd_read.bufferLength / kCDSectorSizeCDDA;
}

- (NSString *)		readMCN
{
	dk_cd_read_mcn_t	cd_read_mcn;
	
	bzero(&cd_read_mcn, sizeof(cd_read_mcn));
	
	if(-1 == ioctl([self fileDescriptor], DKIOCCDREADMCN, &cd_read_mcn)) {
		[self logMessage:NSLocalizedStringFromTable(@"Unable to read the disc's media catalog number (MCN)", @"Exceptions", @"")];
		return nil;
	}
	
	return [NSString stringWithCString:cd_read_mcn.mcn encoding:NSASCIIStringEncoding];
}

- (NSString *)		readISRC:(unsigned)track
{
	dk_cd_read_isrc_t	cd_read_isrc;
	
	bzero(&cd_read_isrc, sizeof(cd_read_isrc));
	
	cd_read_isrc.track			= track;
	
	if(-1 == ioctl([self fileDescriptor], DKIOCCDREADISRC, &cd_read_isrc)) {
		[self logMessage:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Unable to read the international standard recording code (ISRC) for track %i", @"Exceptions", @""), track]];
		return nil;
	}
	
	return [NSString stringWithCString:cd_read_isrc.isrc encoding:NSASCIIStringEncoding];
}

@end
