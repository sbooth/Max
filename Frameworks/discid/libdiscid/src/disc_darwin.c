/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2006 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

     $Id: mb_darwin.cpp,v 1.4 2005/10/28 22:05:27 robert Exp $

----------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>
#include <IOKit/storage/IOCDTypes.h>
#include <IOKit/storage/IOCDMediaBSDClient.h>

#include "discid/discid_private.h"

#define MB_DEFAULT_DEVICE "/dev/rdisk1";
#define TOC_BUFFER_LEN 1024

char *mb_disc_get_default_device_unportable(void) {
	return MB_DEFAULT_DEVICE;
}

int mb_disc_read_unportable(mb_disc_private *disc, const char *device) {
	int fd;
	int i;
	dk_cd_read_toc_t toc;
	CDTOC *cdToc;
  
	if (device == NULL)
	    device = MB_DEFAULT_DEVICE;
  
	fd = open(device, O_RDONLY | O_NONBLOCK);
	if (fd < 0) {
	    snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,  "Cannot open '%s'", device);
	    return 0;
	}
  
	memset(&toc, 0, sizeof(toc));
	toc.format = kCDTOCFormatTOC;
	toc.formatAsTime = 0;
	toc.buffer = (char *)malloc(TOC_BUFFER_LEN);
	toc.bufferLength = TOC_BUFFER_LEN;
	if (ioctl(fd, DKIOCCDREADTOC, &toc) < 0 ) {
	    snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,  "Cannot read TOC from '%s'", device);
	    free(toc.buffer);
	    return 0;
	}
	if ( toc.bufferLength < sizeof(CDTOC) ) {
	    snprintf(disc->error_msg, MB_ERROR_MSG_LENGTH,  "Short TOC was returned from '%s'", device);
	    free(toc.buffer);
	    return 0;
	}
  
	cdToc = (CDTOC *)toc.buffer;
	int numDesc = CDTOCGetDescriptorCount(cdToc);
  
	int numTracks = 0;
	for(i = 0; i < numDesc; i++)
	{
	    CDTOCDescriptor *desc = &cdToc->descriptors[i];
  
	    if (desc->session > 1)
		continue;
  
	    if (desc->point == 0xA2 && desc->adr == 1)
		 disc->track_offsets[0] = CDConvertMSFToLBA(desc->p) + 150; 
  
	    if (desc->point <= 99 && desc->adr == 1)
		 disc->track_offsets[1 + numTracks++] = CDConvertMSFToLBA(desc->p) + 150; 
	}
	disc->first_track_num = 1;
	disc->last_track_num = numTracks;
  
	close(fd);
	free(toc.buffer);
  
	return 1;
}
