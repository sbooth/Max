/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   Copyright (C) 1999 Winston Chang
   
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

     $Id: mb_solaris.cpp 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/

//  could someone with access to a Solaris box please tell
//  me what headers are necessary and what not?

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/byteorder.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>         // ioctl()
#include <fcntl.h>
#include <assert.h>

#include "mb.h"
#include "diskid.h"
#include "config.h"


//  this is an assumption based on a remark from Solaris 2.7 eject(1)
//
//    http://www.freebsd.org/cgi/man.cgi?query=eject&apropos=0&manpath=SunOS+5.7
//
//  or do we have a /dev/cdrom here like Linux does?

MUSICBRAINZ_DEVICE DEFAULT_DEVICE = "/dev/dsk/c0t6d0s2";



int ReadTOCHeader(int fd, 
                  int& first, 
                  int& last)
{
   struct cdrom_tochdr th;

   int ret = ioctl(fd,
                   CDROMREADTOCHDR, 
                   &th);

   if (!ret)
   {
      first = th.cdth_trk0;
      last  = th.cdth_trk1;
   }

   return ret;
}


int ReadTOCEntry(int fd, 
                 int track, 
                 int& lba)
{
    struct cdrom_tocentry te;

    te.cdte_track = (unsigned char) track;
    te.cdte_format = CDROM_LBA;

    int ret = ioctl(fd, 
                    CDROMREADTOCENTRY, 
                    &te);

    if (!ret) {
        assert(te.cdte_format == CDROM_LBA);

        lba = ntohl(te.cdte_addr.lba);  // network to host order (long)
    }

    return ret;
}


bool DiskId::ReadTOC(MUSICBRAINZ_DEVICE device, 
                     MUSICBRAINZ_CDINFO& cdinfo)
{
   int  fd;
   int  first;
   int  last;
   int  lba;
   int  i;
   char err[256];

   if (device == NULL)
   {
       device = DEFAULT_DEVICE;
   }

   fd = open(device, O_RDONLY);
   if (fd < 0)
   {
       sprintf(err, "Cannot open '%s'", device);
       ReportError(err);
       return false;
   }

   // Initialize cdinfo to all zeroes.
   memset(&cdinfo, 0, sizeof(MUSICBRAINZ_CDINFO));

   // Find the number of the first track (usually 1) and the last track.
   if (ReadTOCHeader(fd, first, last))
   {
      ReportError("Cannot read table of contents.");
      close(fd);
      return false;
   }

   // Do some basic error checking.
   if (last==0)
   {
      ReportError("This disk has no tracks.");
      close(fd);	
      return false;
   }

   // Get the logical block address (lba) for the end of the audio data.
   // The "LEADOUT" track is the track beyond the final audio track
   // so we're looking for the block address of the LEADOUT track.
   ReadTOCEntry(fd, 
                CDROM_LEADOUT, 
                lba);

   cdinfo.FrameOffset[0] = lba / 4 + 150;  // Solaris 2048 bytes blocksize hack

   // Now, for every track, find out the block address where it starts.
   for (i = first; i <= last; i++)
   {
      ReadTOCEntry(fd, i, lba);
      cdinfo.FrameOffset[i] = lba / 4 + 150;  // note factor 1/4
   }

   cdinfo.FirstTrack = first;
   cdinfo.LastTrack = last;

   close(fd);

   return true;
}
