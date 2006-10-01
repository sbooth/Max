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

     $Id: mb_linux.cpp 691 2004-04-26 20:10:44Z robert $

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

#include "mb.h"
#include "diskid.h"
#include "config.h"


#define XA_INTERVAL ((60 + 90 + 2) * CD_FRAMES)


MUSICBRAINZ_DEVICE DEFAULT_DEVICE = "/dev/cdrom";


int ReadTOCHeader(int fd, 
                  int& first, 
                  int& last)
{
   struct cdrom_tochdr th;
   struct cdrom_multisession ms;

   int ret = ioctl(fd,
                   CDROMREADTOCHDR,
                   &th);

   if (!ret)
   {
      // Hide the last track if this is a multisession disc (note that
      // currently only dual-session discs with one track in the second
      // session are handled correctly).
      ms.addr_format = CDROM_LBA;
      ret = ioctl(fd,
                  CDROMMULTISESSION,
                  &ms);

      first = th.cdth_trk0;
      last = th.cdth_trk1;
      if (ms.xa_flag)
         last--;
   }

   return ret;
}


int ReadTOCEntry(int fd, 
                 int track, 
                 int& lba)
{
   struct cdrom_tocentry te;
   struct cdrom_multisession ms;
   int ret = 0;

   if (track == CDROM_LEADOUT)
   {
      // For a multisession disc, the location of the single-session lead-out
      // track must be calculated based on where the last session begins.
      ms.addr_format = CDROM_LBA;
      ret = ioctl(fd,
                  CDROMMULTISESSION,
                  &ms);

      if (ms.xa_flag)
      {
         lba = ms.addr.lba - XA_INTERVAL;
         return ret;
      }
   }

   if (!ret)
   {
      te.cdte_track = track;
      te.cdte_format = CDROM_LBA;

      ret = ioctl(fd, 
                  CDROMREADTOCENTRY, 
                  &te);

      assert(te.cdte_format == CDROM_LBA);

      lba = te.cdte_addr.lba;
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

   if (device == NULL)
   {
       device = DEFAULT_DEVICE;
   }

   fd = open(device, O_RDONLY | O_NONBLOCK);
   if (fd < 0)
   {
       char err[256];
       sprintf(err,"Cannot open '%s'", device);
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

   cdinfo.FrameOffset[0] = lba + 150;

   // Now, for every track, find out the block address where it starts.
   for (i = first; i <= last; i++)
   {
      ReadTOCEntry(fd, i, lba);
      cdinfo.FrameOffset[i] = lba + 150;
   }

   cdinfo.FirstTrack = first;
   cdinfo.LastTrack = last;

   close(fd);

   return true;
}
