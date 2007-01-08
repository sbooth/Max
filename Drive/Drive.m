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

#import "Drive.h"

#include <IOKit/storage/IOCDTypes.h>
#include <IOKit/storage/IOCDMediaBSDClient.h>
#include <util.h> // opendev

#import "LogController.h"

@interface Drive (Private)
- (void)				logMessage:(NSString *)message;

- (unsigned)			countOfTracks;
- (unsigned)			countOfSessions;

- (TrackDescriptor *)	objectInTracksAtIndex:(unsigned)index;
- (SessionDescriptor *)	objectInSessionsAtIndex:(unsigned)index;

- (void)				setFirstSession:(unsigned)session;
- (void)				setLastSession:(unsigned)session;

- (void)				readTOC;
- (int)					fileDescriptor;

- (unsigned)			readCD:(void *)buffer sectorAreas:(uint8_t)sectorAreas startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount;
@end

@implementation Drive

- (id) initWithDeviceName:(NSString *)deviceName
{
	NSParameterAssert(nil != deviceName);
	
	if((self = [super init])) {
		
		_deviceName		= [deviceName retain];
		_fd				= -1;
		_cacheSize		= 2 * 1024 * 1024;
		
		_sessions		= [[NSMutableArray alloc] init];
		_tracks			= [[NSMutableArray alloc] init];
		
		_fd				= opendev((char *)[[self deviceName] fileSystemRepresentation], O_RDONLY | O_NONBLOCK, 0, NULL);
		NSAssert(-1 != _fd, NSLocalizedStringFromTable(@"Unable to open the drive for reading.", @"Exceptions", @""));
				
		[self readTOC];
		
		return self;
	}
	
	return nil;
}

- (void)			dealloc
{
	if(-1 == close(_fd)) {
		NSException *exception;
		
		exception =  [NSException exceptionWithName:@"IOException"
											 reason:NSLocalizedStringFromTable(@"Unable to close the drive.", @"Exceptions", @"")					
										   userInfo:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:errno], [NSString stringWithCString:strerror(errno) encoding:NSASCIIStringEncoding], nil] forKeys:[NSArray arrayWithObjects:@"errorCode", @"errorString", nil]]];

		[self logMessage:[exception description]];
	}
	
	_fd = -1;
	
	[_deviceName release];		_deviceName = nil;
	[_sessions release];		_sessions = nil;
	[_tracks release];			_tracks = nil;
	
	[super dealloc];
}

- (unsigned)			cacheSize									{ return _cacheSize; }
- (unsigned)			cacheSectorSize								{ return (([self cacheSize] / kCDSectorSizeCDDA) + 1); }
- (void)				setCacheSize:(unsigned)cacheSize			{ _cacheSize = cacheSize; }

- (NSString *)			deviceName									{ return [[_deviceName retain] autorelease]; }

// Disc track information
- (unsigned)			sessionContainingSector:(unsigned)sector
{
	return [self sessionContainingSectorRange:[SectorRange rangeWithSector:sector]];
}

- (unsigned)			sessionContainingSectorRange:(SectorRange *)sectorRange
{
	unsigned		session;
	unsigned		sessionFirstSector;
	unsigned		sessionLastSector;
	SectorRange		*sessionSectorRange;
	
	for(session = [self firstSession]; session <= [self lastSession]; ++session) {

		sessionFirstSector		= [self firstSectorForTrack:[self firstTrackForSession:session]];
		sessionLastSector		= [self lastSectorForTrack:[self lastTrackForSession:session]];
		
		sessionSectorRange		= [SectorRange rangeWithFirstSector:sessionFirstSector lastSector:sessionLastSector];
		
		if([sessionSectorRange containsSectorRange:sectorRange]) {
			return session;
		}		
	}
	
	return NSNotFound;
}

// Disc session information
- (unsigned)			firstSession								{ return _firstSession; }
- (unsigned)			lastSession									{ return _lastSession; }

- (SessionDescriptor *)	sessionNumber:(unsigned)number
{
	SessionDescriptor	*session	= nil;
	unsigned			i;
	
	for(i = 0; i < [self countOfSessions]; ++i) {
		session = [self objectInSessionsAtIndex:i];
		if([session number] == number) {
			return session;
		}
	}
	
	return nil;
}

// First and last track and lead out information (session-based)
- (unsigned)			firstTrackForSession:(unsigned)session		{ return [[self sessionNumber:session] firstTrack]; }
- (unsigned)			lastTrackForSession:(unsigned)session		{ return [[self sessionNumber:session] lastTrack]; }
- (unsigned)			leadOutForSession:(unsigned)session			{ return [[self sessionNumber:session] leadOut]; }

- (unsigned)			firstSectorForSession:(unsigned)session		{ return [self firstSectorForTrack:[[self sessionNumber:session] firstTrack]]; }
- (unsigned)			lastSectorForSession:(unsigned)session		{ return [[self sessionNumber:session] leadOut] - 1; }

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

// Track sector information
- (unsigned)			firstSectorForTrack:(unsigned)number		{ return [[self trackNumber:number] firstSector]; }
- (unsigned)			lastSectorForTrack:(unsigned)number
{
	TrackDescriptor		*thisTrack		= [self trackNumber:number];
	TrackDescriptor		*nextTrack		= [self trackNumber:number + 1];
	
	if(nil == thisTrack) {
		@throw [NSException exceptionWithName:@"IllegalArgumentException" reason:[NSString stringWithFormat:@"Track %u doesn't exist", number] userInfo:nil];
	}
	
	return ([self lastTrackForSession:[thisTrack session]] == number ? [self lastSectorForSession:[thisTrack session]] : [nextTrack firstSector] - 1);
}

- (uint16_t)		speed
{
	uint16_t	speed	= 0;
	
	if(-1 == ioctl([self fileDescriptor], DKIOCCDGETSPEED, &speed)) {
		[self logMessage:NSLocalizedStringFromTable(@"Unable to get the drive's speed", @"Exceptions", @"")];
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
	unsigned		session;
	unsigned		requiredReadSize;
	unsigned		sessionFirstSector, sessionLastSector;
	unsigned		preSectorsAvailable, postSectorsAvailable;
	unsigned		sectorsRemaining, sectorsRead, boundary;
	
	requiredReadSize		= [self cacheSectorSize];
	session					= [self sessionContainingSectorRange:range];
	sessionFirstSector		= [self firstSectorForSession:session];
	sessionLastSector		= [self lastSectorForSession:session];
	preSectorsAvailable		= [range firstSector] - sessionFirstSector;
	postSectorsAvailable	= sessionLastSector - [range lastSector];
	
	@try {
		// Allocate the buffer
		bufferLen	= requiredReadSize < 1024 ? requiredReadSize : 1024;
		buffer		= calloc(bufferLen, kCDSectorSizeCDDA);
		NSAssert(NULL != buffer, NSLocalizedStringFromTable(@"Unable to allocate memory.", @"Exceptions", @""));
		
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
								  startSector:sessionFirstSector + (requiredReadSize - sectorsRemaining)
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				NSAssert(0 != sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @""));
				
				sectorsRemaining -= sectorsRead;
			}
		}
		else if(postSectorsAvailable >= requiredReadSize) {
			sectorsRemaining = requiredReadSize;
			while(0 < sectorsRemaining) {
				sectorsRead = [self readAudio:buffer
								  startSector:sessionLastSector - sectorsRemaining
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				NSAssert(0 != sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @""));

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
								  startSector:sessionFirstSector + (boundary - sectorsRemaining)
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				NSAssert(0 != sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @""));

				sectorsRemaining -= sectorsRead;
			}
			
			// Read the remaining sectors from after the range
			boundary			= [range lastSector] + 1;
			sectorsRemaining	= requiredReadSize - sectorsRemaining;
			
			// This should never happen; we tested for it above
			if(sectorsRemaining > (sessionLastSector - boundary)) {
				NSLog(@"fnord!");
			}
			
			while(0 < sectorsRemaining) {
				sectorsRead = [self readAudio:buffer
								  startSector:sessionLastSector - sectorsRemaining
								  sectorCount:(bufferLen < sectorsRemaining ? bufferLen : sectorsRemaining)];
				NSAssert(0 != sectorsRead, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @""));

				sectorsRemaining -= sectorsRead;
			}
			
		}
	}
	
	@finally {
		free(buffer);
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
	return [self readCD:buffer sectorAreas:kCDSectorAreaUser startSector:startSector sectorCount:sectorCount];
}

- (unsigned)		readQSubchannel:(void *)buffer sector:(unsigned)sector
{
	return [self readQSubchannel:buffer startSector:sector sectorCount:1];
}

- (unsigned)		readQSubchannel:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readQSubchannel:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (unsigned)		readQSubchannel:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	return [self readCD:buffer sectorAreas:kCDSectorAreaSubChannelQ startSector:startSector sectorCount:sectorCount];
}

- (unsigned)		readErrorFlags:(void *)buffer sector:(unsigned)sector
{
	return [self readErrorFlags:buffer startSector:sector sectorCount:1];
}

- (unsigned)		readErrorFlags:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readErrorFlags:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (unsigned)		readErrorFlags:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	return [self readCD:buffer sectorAreas:kCDSectorAreaErrorFlags startSector:startSector sectorCount:sectorCount];
}

- (unsigned)		readAudioAndQSubchannel:(void *)buffer sector:(unsigned)sector
{
	return [self readAudioAndQSubchannel:buffer startSector:sector sectorCount:1];
}

- (unsigned)		readAudioAndQSubchannel:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudioAndQSubchannel:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (unsigned)		readAudioAndQSubchannel:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	return [self readCD:buffer sectorAreas:(kCDSectorAreaUser | kCDSectorAreaSubChannelQ) startSector:startSector sectorCount:sectorCount];
}

- (unsigned)		readAudioAndErrorFlags:(void *)buffer sector:(unsigned)sector
{
	return [self readAudioAndErrorFlags:buffer startSector:sector sectorCount:1];
}

- (unsigned)		readAudioAndErrorFlags:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudioAndErrorFlags:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (unsigned)		readAudioAndErrorFlags:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	return [self readCD:buffer sectorAreas:(kCDSectorAreaUser | kCDSectorAreaErrorFlags) startSector:startSector sectorCount:sectorCount];
}

- (unsigned)		readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sector:(unsigned)sector
{
	return [self readAudioAndErrorFlagsWithQSubchannel:buffer startSector:sector sectorCount:1];
}

- (unsigned)		readAudioAndErrorFlagsWithQSubchannel:(void *)buffer sectorRange:(SectorRange *)range
{
	return [self readAudioAndErrorFlagsWithQSubchannel:buffer startSector:[range firstSector] sectorCount:[range length]];
}

- (unsigned)		readAudioAndErrorFlagsWithQSubchannel:(void *)buffer startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	return [self readCD:buffer sectorAreas:(kCDSectorAreaUser | kCDSectorAreaErrorFlags | kCDSectorAreaSubChannelQ) startSector:startSector sectorCount:sectorCount];
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

- (NSString *)		description
{
	return [NSString stringWithFormat:@"{\n\tDevice: %@\n\tFirst Session: %u\n\tLast Session: %u\n}", [self deviceName], [self firstSession], [self lastSession]];
}

@end

@implementation Drive (Private)

- (void)				logMessage:(NSString *)message
{
	[[LogController sharedController] performSelectorOnMainThread:@selector(logMessage:) withObject:message waitUntilDone:NO];
}

- (unsigned)			countOfTracks								{ return [_tracks count]; }
- (unsigned)			countOfSessions								{ return [_sessions count]; }

- (TrackDescriptor *)	objectInTracksAtIndex:(unsigned)index		{ return [_tracks objectAtIndex:index]; }
- (SessionDescriptor *)	objectInSessionsAtIndex:(unsigned)index		{ return [_sessions objectAtIndex:index]; }

- (void)				setFirstSession:(unsigned)session			{ _firstSession = session; }
- (void)				setLastSession:(unsigned)session			{ _lastSession = session; }

- (void)			readTOC
{
	int					result;
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
	cd_read_toc.buffer			= buffer;
	cd_read_toc.bufferLength	= sizeof(buffer);
	
	result = ioctl([self fileDescriptor], DKIOCCDREADTOC, &cd_read_toc);
	NSAssert(-1 != result, NSLocalizedStringFromTable(@"Unable to read the disc's table of contents.", @"Exceptions", @""));
	
	toc				= (CDTOC*)buffer;
	numDescriptors	= CDTOCGetDescriptorCount(toc);
	
	[self setFirstSession:toc->sessionFirst];
	[self setLastSession:toc->sessionLast];
	
	// Set up objects that will hold first sector, last sector and lead out information for each session
	for(i = [self firstSession]; i <= [self lastSession]; ++i) {
		SessionDescriptor *session = [[SessionDescriptor alloc] init];
		[session setNumber:i];
		[_sessions addObject:[session autorelease]];
	}
	
	// Iterate through each descriptor and extract the information we need
	for(i = 0; i < numDescriptors; ++i) {
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
		else if(0xA0 == desc->point && 1 == desc->adr) {
			[[self sessionNumber:desc->session] setFirstTrack:desc->p.minute];
/*			NSLog(@"Disc type:                 %d (%s)\n", (int)desc->p.second,
				  (0x00 == desc->p.second) ? "CD-DA, or CD-ROM with first track in Mode 1":
				  (0x10 == desc->p.second) ? "CD-I disc":
				  (0x20 == desc->p.second) ? "CD-ROM XA disc with first track in Mode 2" : "Unknown");*/
		}
		// Last track
		else if(0xA1 == desc->point && 1 == desc->adr) {
			[[self sessionNumber:desc->session] setLastTrack:desc->p.minute];
		}
		// Lead-out
		else if(0xA2 == desc->point && 1 == desc->adr) {
			[[self sessionNumber:desc->session] setLeadOut:CDConvertMSFToLBA(desc->p)];
		}
/*		else if(0xB0 == desc->point && 5 == desc->adr) {
			NSLog(@"Next possible track start: %02d:%02d.%02d\n",
				  (int)desc->address.minute, (int)desc->address.second, (int)desc->address.frame);
			NSLog(@"Number of ptrs in Mode 5:  %d\n",
				  (int)desc->zero);
			NSLog(@"Last possible lead-out:    %02d:%02d.%02d\n",
				  (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame);
		}
		else if(0xB1 == desc->point && 5 == desc->adr) {
			NSLog(@"Skip interval pointers:    %d\n", (int)desc->p.minute);
			NSLog(@"Skip track pointers:       %d\n", (int)desc->p.second);
		}
		else if(0xB2 <= desc->point && 0xB2 >= desc->point && 5 == desc->adr) {
			NSLog(@"Skip numbers:              %d, %d, %d, %d, %d, %d, %d\n",
				  (int)desc->address.minute, (int)desc->address.second, (int)desc->address.frame,
				  (int)desc->zero, (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame);
		}
		else if(1 == desc->point && 40 >= desc->point && 5 == desc->adr) {
			NSLog(@"Skip from %02d:%02d.%02d to %02d:%02d.%02d\n",
				  (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame,
				  (int)desc->address.minute, (int)desc->address.second, (int)desc->address.frame);
		}
		else if(0xC0 == desc->point && 5 == desc->adr) {
			NSLog(@"Optimum recording power:   %d\n", (int)desc->address.minute);
			NSLog(@"Application code:          %d\n", (int)desc->address.second);
			NSLog(@"Start of first lead-in:    %02d:%02d.%02d\n",
				  (int)desc->p.minute, (int)desc->p.second, (int)desc->p.frame);
		}*/
	}
}

- (int)					fileDescriptor								{ return _fd; }

// Implementation method
- (unsigned)		readCD:(void *)buffer sectorAreas:(uint8_t)sectorAreas startSector:(unsigned)startSector sectorCount:(unsigned)sectorCount
{
	int				result;
	dk_cd_read_t	cd_read;
	unsigned		blockSize		= 0;
	
	if(kCDSectorAreaUser & sectorAreas)					{ blockSize += kCDSectorSizeCDDA; }
	if(kCDSectorAreaErrorFlags & sectorAreas)			{ blockSize += kCDSectorSizeErrorFlags; }
	if(kCDSectorAreaSubChannelQ & sectorAreas)			{ blockSize += kCDSectorSizeQSubchannel; }
	
	bzero(&cd_read, sizeof(cd_read));
	bzero(buffer, blockSize * sectorCount);
	
	cd_read.offset			= blockSize * startSector;
	cd_read.sectorArea		= sectorAreas;
	cd_read.sectorType		= kCDSectorTypeCDDA;
	cd_read.buffer			= buffer;
	cd_read.bufferLength	= blockSize * sectorCount;
	
	result = ioctl([self fileDescriptor], DKIOCCDREAD, &cd_read);
	NSAssert(-1 != result, NSLocalizedStringFromTable(@"Unable to read from the disc.", @"Exceptions", @""));
	
	return cd_read.bufferLength / blockSize;
}

@end
