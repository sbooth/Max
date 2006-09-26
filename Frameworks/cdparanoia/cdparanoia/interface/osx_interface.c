/*
 *  $Id: MediaController.m 134 2005-11-19 21:43:36Z me $
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

#include "osx_interface.h"
#include "utils.h"

#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/storage/IOCDMedia.h>
#include <IOKit/storage/IOCDTypes.h>
#include <IOKit/storage/IOCDMediaBSDClient.h>

#include <fcntl.h>
#include <sys/param.h>
#include <paths.h>


// ==================================================
// From Apple's CDROMSample.c
// ==================================================
static kern_return_t 
findEjectableCDMedia(io_iterator_t *mediaIterator)
{
    kern_return_t				kernResult; 
    mach_port_t					masterPort;
    CFMutableDictionaryRef		classesToMatch;
	
    kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if(KERN_SUCCESS != kernResult) {
		return kernResult;
    }
	
    classesToMatch = IOServiceMatching(kIOCDMediaClass); 
    if(NULL == classesToMatch) {
		return kernResult;
    }
    else {
		CFDictionarySetValue(classesToMatch, CFSTR(kIOMediaEjectableKey), kCFBooleanTrue); 
    }
    
    kernResult = IOServiceGetMatchingServices(masterPort, classesToMatch, mediaIterator);    
    if(KERN_SUCCESS != kernResult) {
		return kernResult;
    }
    
    return kernResult;
}
// ==================================================
// End Apple code
// ==================================================

static char*
osx_get_bsd_path(io_object_t media)
{
	char			bsdPath[ MAXPATHLEN ];
	ssize_t			devPathLength;
	CFTypeRef		deviceNameAsCFString;
	
	/* Get the BSD path for the device */
	deviceNameAsCFString = IORegistryEntryCreateCFProperty(media, CFSTR(kIOBSDNameKey), kCFAllocatorDefault, 0);
	if(NULL == deviceNameAsCFString) {
		return NULL;
	}
	
	strcpy(bsdPath, _PATH_DEV);
	
	/* Add "r" before the BSD node name from the I/O Registry to specify the raw disk
		node. The raw disk nodes receive I/O requests directly and do not go through
		the buffer cache. */	
	strcat(bsdPath, "r");
	
	devPathLength = strlen(bsdPath);
	
	if(FALSE == CFStringGetCString(deviceNameAsCFString, bsdPath + devPathLength, MAXPATHLEN - devPathLength, kCFStringEncodingASCII)) {
		CFRelease(deviceNameAsCFString);
		return NULL;
	}
	else {		
		CFRelease(deviceNameAsCFString);
		return strdup(bsdPath);
	}
}

static int 
osx_set_speed(cdrom_drive *d, int speed)
{
	if(-1 != d->fd) {
		return ioctl(d->fd, DKIOCCDSETSPEED, speed);
	}
	else {
		return 0;
	}
}

static int
osx_enable_cdda(cdrom_drive *d, int onoff)
{
	return 0;
}

int 
osx_init_drive(cdrom_drive *d)
{
	CDTOC					*toc;
	CFMutableDictionaryRef	properties;
	CFDataRef				data;
	CFRange					range;
	CFIndex					tocSize;
	
	kern_return_t			kernResult;
	
	unsigned				i, leadout;
	UInt32					numDescriptors;
	
	
	kernResult = IORegistryEntryCreateCFProperties(d->io_object, &properties, kCFAllocatorDefault, kNilOptions);
	if(KERN_SUCCESS != kernResult) {
		cderror(d, "IORegistryEntryCreateCFProperties");
		return -1;
	}
		
	data = (CFDataRef) CFDictionaryGetValue(properties, CFSTR(kIOCDMediaTOCKey));
	if(NULL == data) {
		cderror(d, "CFDictionaryGetValue");
		return -1;
	}
	
	tocSize		= CFDataGetLength(data) + 1;
	range		= CFRangeMake(0, tocSize);
	
	toc = (CDTOC *) malloc(tocSize);
	if(NULL == toc) {
		cderror(d, "malloc() failed");
		CFRelease(properties);
		return -1;
	}
	CFDataGetBytes(data, range, (unsigned char *) toc);	
	CFRelease(properties);

	d->tracks = 0;
		
	numDescriptors = CDTOCGetDescriptorCount(toc);
	for(i = 0; i < numDescriptors; ++i) {		
		CDTOCDescriptor *desc = &toc->descriptors[i];

		if(99 >= desc->point && 1 == desc->adr) {
			d->disc_toc[d->tracks].bTrack			= desc->point;
			d->disc_toc[d->tracks].bFlags			= (desc->adr << 4) | (desc->control & 0x0f);
			d->disc_toc[d->tracks].dwStartSector	= CDConvertMSFToLBA(desc->p);

			d->tracks++;
		}
		else if(0xA2 == desc->point && 1 == desc->adr) {
			leadout = i;
		}		
	}

	d->disc_toc[d->tracks].bTrack			= (&toc->descriptors[leadout])->point;
	d->disc_toc[d->tracks].bFlags			= ((&toc->descriptors[leadout])->adr << 4) | ((&toc->descriptors[leadout])->control & 0x0f);
	d->disc_toc[d->tracks].dwStartSector	= CDConvertMSFToLBA((&toc->descriptors[leadout])->p);
	
	d->enable_cdda							= osx_enable_cdda;
	d->set_speed							= osx_set_speed;
	d->read_audio							= osx_read_audio;
	
	d->nsectors								= 32;
	d->opened								= 1;

	free(toc);
	
	return 0;	
}

long 
osx_read_audio(cdrom_drive *d, void *buffer, long beginsector, long sectors)
{
	dk_cd_read_t	cd_read;
	
	
	memset(&cd_read, 0, sizeof(cd_read));
	
	cd_read.offset			= beginsector * kCDSectorSizeCDDA;
	cd_read.sectorArea		= kCDSectorAreaUser;
	cd_read.sectorType		= kCDSectorTypeCDDA;
	cd_read.buffer			= buffer;
	cd_read.bufferLength	= kCDSectorSizeCDDA * sectors;
	
	if(-1 == ioctl(d->fd, DKIOCCDREAD, &cd_read)) {
		return 0;
	}
	
	return cd_read.bufferLength / kCDSectorSizeCDDA;
}

/* Attempt to use dev as the device */
cdrom_drive* 
osx_cdda_identify(const char *dev, int messagedest, char **messages)
{
	kern_return_t	kernResult;
	io_iterator_t	mediaIterator;
	io_object_t		nextMedia;
	
	
	kernResult = findEjectableCDMedia(&mediaIterator);
	if(KERN_SUCCESS != kernResult) {
		return NULL;
	}
	
	while((nextMedia = IOIteratorNext(mediaIterator))) {
		char			*device_name;
		cdrom_drive		*result;
		int				fd;
		
		device_name = osx_get_bsd_path(nextMedia);
		if(device_name && 0 == strcmp(dev, device_name)) {
			
			result = calloc(1, sizeof(cdrom_drive));
			if(NULL == result) {
				IOObjectRelease(mediaIterator);
				return NULL;
			}
			
			kernResult = IOObjectRetain(nextMedia);
			if(KERN_SUCCESS != kernResult) {
				IOObjectRelease(mediaIterator);
				free(result);
				return NULL;
			}
			
			result->device_name = device_name;
			fd					= open(result->device_name, O_RDONLY | O_NONBLOCK);

			if(-1 == fd) {
				IOObjectRelease(mediaIterator);
				IOObjectRelease(nextMedia); /* ignore result since we already have an error */
				free(result->device_name);
				free(result);
				return NULL;
			}
			
			result->io_object		= nextMedia;		
			result->fd				= fd;
			result->bigendianp		= -1;
			result->nsectors		= -1;
			
			IOObjectRelease(mediaIterator);			
			return result;
		}
	}
	
	IOObjectRelease(mediaIterator);
	return NULL;
}

cdrom_drive* 
osx_find_a_cdrom(int messagedest, char **messages)
{
	kern_return_t	kernResult;
	io_iterator_t	mediaIterator;
	io_object_t		nextMedia;
	

	kernResult = findEjectableCDMedia(&mediaIterator);
	if(KERN_SUCCESS != kernResult) {
		return NULL;
	}
	
	/* Use the first drive if found */
	if((nextMedia = IOIteratorNext(mediaIterator))) {
		cdrom_drive		*result;
		int				fd;
		
		result = calloc(1, sizeof(cdrom_drive));
		if(NULL == result) {
			IOObjectRelease(mediaIterator);
			return NULL;
		}
		
		kernResult = IOObjectRetain(nextMedia);
		if(KERN_SUCCESS != kernResult) {
			IOObjectRelease(mediaIterator);
			free(result);
			return NULL;
		}
		
		result->device_name = osx_get_bsd_path(nextMedia);
		if(NULL == result->device_name) {
			IOObjectRelease(mediaIterator);
			IOObjectRelease(nextMedia); /* ignore result since we already have an error */
			free(result);
			return NULL;			
		}
		
		fd = open(result->device_name, O_RDONLY | O_NONBLOCK);
		
		if(-1 == fd) {
			IOObjectRelease(mediaIterator);
			IOObjectRelease(nextMedia); /* ignore result since we already have an error */
			free(result->device_name);
			free(result);
			return NULL;
		}

		result->io_object		= nextMedia;		
		result->fd				= fd;
		result->bigendianp		= -1;
		result->nsectors		= -1;
		
		IOObjectRelease(mediaIterator);
		return result;
	}
	else {
		IOObjectRelease(mediaIterator);
		return NULL;
	}
}

int
osx_cdda_close(cdrom_drive *d)
{
	kern_return_t kernResult;
	
	
	kernResult = IOObjectRelease(d->io_object);
	if(KERN_SUCCESS != kernResult) {
		cderror(d, "IOObjectRelease() failed");
		/* what to do ... */		
	}
	
	if(-1 == close(d->fd)) {
		/* what to do ... */
		cderror(d, "close() failed");
	}
	
	free(d->device_name);
	
	return 0;
}

char * 
cdda_disc_mcn(cdrom_drive *d)
{
	dk_cd_read_mcn_t	cd_read_mcn;
	
	
	memset(&cd_read_mcn, 0, sizeof(cd_read_mcn));

	if(-1 == ioctl(d->fd, DKIOCCDREADMCN, &cd_read_mcn)) {
		return NULL;
	}
	
	return strdup(cd_read_mcn.mcn);
}

char * 
cdda_track_isrc(cdrom_drive *d, int track)
{
	dk_cd_read_isrc_t	cd_read_isrc;
	
	
	memset(&cd_read_isrc, 0, sizeof(cd_read_isrc));
	
	cd_read_isrc.track			= track;

	if(-1 == ioctl(d->fd, DKIOCCDREADISRC, &cd_read_isrc)) {
		return NULL;
	}
	
	return strdup(cd_read_isrc.isrc);
}
