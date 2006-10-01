/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
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
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

     $Id: mb_darwin.cpp 761 2005-10-28 22:05:27Z robert $

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

#include "mb.h"
#include "diskid.h"
#include "config.h"


MUSICBRAINZ_DEVICE DEFAULT_DEVICE = "/dev/rdisk1";

bool DiskId::ReadTOC(MUSICBRAINZ_DEVICE device, 
                     MUSICBRAINZ_CDINFO& cdinfo)
{
   int fd;
   int i;
   dk_cd_read_toc_t toc;
   CDTOC *cdToc;

   if (device == NULL)
   {
       device = DEFAULT_DEVICE;
   }

   fd = open(device, O_RDONLY | O_NONBLOCK);
   if (fd < 0)
   {
       char err[256];

       sprintf(err, "Cannot open '%s'", device);
       ReportError(err);

       return false;
   }

   memset(&toc, 0, sizeof(toc));
   toc.format = kCDTOCFormatTOC;
   toc.formatAsTime = 0;
   toc.buffer = new char[1024];
   toc.bufferLength = 1024;
   if (ioctl(fd, DKIOCCDREADTOC, &toc) < 0 )
   {
       delete [] (char *)toc.buffer;
       return false;
   }
   if ( toc.bufferLength < sizeof(CDTOC) )
   {
       delete [] (char *)toc.buffer;
       return false;
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
            cdinfo.FrameOffset[0] = CDConvertMSFToLBA(desc->p) + 150; 

       if (desc->point <= 99 && desc->adr == 1)
            cdinfo.FrameOffset[1 + numTracks++] = CDConvertMSFToLBA(desc->p) + 150; 
   }
   cdinfo.FirstTrack = 1;
   cdinfo.LastTrack = numTracks;

   close(fd);

   delete [] (char *)toc.buffer;

   return true;
}
