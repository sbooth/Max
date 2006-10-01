/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   Copyright (C) 1999 Ben Wong
   
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

     $Id: mb_irix.cpp 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>

#include <netinet/in.h>
#include <signal.h>

#include "mb.h"
#include "diskid.h"
#include "config.h"


// Irix will just magically find the CD-ROM when told to open NULL.
MUSICBRAINZ_DEVICE DEFAULT_DEVICE = 0;


int ReadTOCHeader(CDPLAYER* fd, 
                  int& first, 
                  int& last)
{
    CDSTATUS tochdr;

    // CDgetstatus returns 0 on error but we return 0 on success.
    int ret = !CDgetstatus(fd, &tochdr);        

    if (!ret)
    {
        first = tochdr.first;
        last  = tochdr.last;
    }

    return ret;
}


int ReadTOCEntry(CDPLAYER* fd, 
                 int track, 
                 int& lba)
{
    CDTRACKINFO trackinfo;

    // CDgettrackinfo returns 0 on error but we return 0 on success.
    int ret = !CDgettrackinfo(fd, track, &trackinfo);

    if (!ret)
    {
        // trackinfo has Min/Sec/Frame but we want a Logical Block Address.
        lba = CDmsftoblock(fd, 
                           trackinfo.start_min,
                           trackinfo.start_sec,
                           trackinfo.start_frame);
    }

    return ret;
}


// Return one past the *end* of the track requested instead of the
// start. (Equivalent to "start of the next track" but works even when
// the next track doesn't exist).

int ReadTOCEntryEnd(CDPLAYER* fd, 
                    int track, 
                    int &lba)
{
    CDTRACKINFO trackinfo;

    // CDgettrackinfo returns 0 on error but we return 0 on success.
    int ret = !CDgettrackinfo(fd, track, &trackinfo);
    if (!ret)
    {
        // trackinfo has Min/Sec/Frame but we want a Logical Block Address.
        lba = CDmsftoblock(fd, 
                           trackinfo.start_min+trackinfo.total_min,
                           trackinfo.start_sec+trackinfo.total_sec,
                           trackinfo.start_frame+trackinfo.total_frame)+1;
    }

    return ret;
}


bool DiskId::ReadTOC(MUSICBRAINZ_DEVICE device, 
                     MUSICBRAINZ_CDINFO& cdinfo)
{
   CDSTATUS status;
   CDPLAYER *fd = CDopen(device, "r");
   int first, last;
   int lba, i;
   char err[256];

   if (!fd || !CDgetstatus(fd, &status))
   {
       sprintf(err, "Cannot open %s", 
              device ? device : "any CD-ROM");

       if (!fd) 
           sprintf(err + strlen(err), ": %s", strerror(errno));

       ReportError(err);

       return false;
   }

   // Check if the CD-ROM is ready, has a disk in it, isn't already playing.
   if (status.state != CD_READY)
   {
       strcpy(err, "The CD-ROM isn't ready. Reason: ");

       switch (status.state) {
       case CD_NODISC: 
           strcat(err, "The drive does not have a CD loaded.");
           break;

       case CD_CDROM:
           strcat(err, "The drive is loaded with a CD-ROM.  Subsequent ");
           strcat(err, "play or read operations will return I/O errors.");
           break;
           
       case CD_ERROR:
           strcat(err, "An error occurred while trying to read the disc or");
           strcat(err, " it table of contents.");
           break;
           
       case CD_PLAYING:
           strcat(err, "The drive is in CD player mode playing an audio ");
           strcat(err, "CD through its audio jacks.");
           break;

       case CD_PAUSED:
       case CD_STILL:
           strcat(err, "The drive is in CD player mode with play paused.");
           break;
           
       default:
           strcat(err, "An unknown error occured.");
       }
       ReportError(err);

       return false;
   }

   // Initialize cdinfo to all zeroes.
   memset(&cdinfo, 0, sizeof(MUSICBRAINZ_CDINFO));

   // Find the number of the first track (usually 1) and the last track.
   if (ReadTOCHeader(fd, first, last))
   {
      ReportError("Cannot read table of contents.");
      CDclose(fd);      
      return false;
   }
   
   // Do some basic error checking.
   if (last==0)
   {
      ReportError("This disk has no tracks.");
      CDclose(fd);      
      return false;
   }

   // Get the block address for the end of the audio data.
   // The "LEADOUT" track is the track beyond the final audio track
   // so we're looking for the block address of the LEADOUT track.
   ReadTOCEntryEnd(fd, last, lba);
   cdinfo.FrameOffset[0] = lba + 150;

   // Now, for every track, find out the block address where it starts.
   for (i = first; i <= last; i++)
   {
      ReadTOCEntry(fd, i, lba);
      cdinfo.FrameOffset[i] = lba + 150;
   }

   cdinfo.FirstTrack = first;
   cdinfo.LastTrack = last;

   CDclose(fd);         

   return true;
}

