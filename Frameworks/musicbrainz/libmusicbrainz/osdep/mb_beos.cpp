/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   Copyright (C) 1999 Stephen van Egmond
   
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

     $Id: mb_beos.cpp 469 2001-07-06 21:32:13Z robert $

----------------------------------------------------------------------------*/

#include "mb.h"
#include "diskid.h"
#include "config.h"

// BeOS layer includes
#include <Path.h>
#include <Directory.h>
#include <String.h>
#include <scsi.h>
#include <Roster.h>

// POSIX layer includes
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <assert.h>


// forward declarations
static void FindCDPlayerDevice();
static uint32 msf_to_lba(uint8 m, uint8 s, uint8 f);

// global variables
BString gCDPlayerDeviceName;
int gCDPlayerDevice;

// initializer -- call before using above globals
status_t gConfigureGlobals() {
    gCDPlayerDevice = 0;
	
    FindCDPlayerDevice();
    if (gCDPlayerDevice == 0) {
        return B_DEV_BAD_DRIVE_NUM;
    }
	
    return B_NO_ERROR;
}

bool DiskId::ReadTOC(char *device, 
                     MUSICBRAINZ_CDINFO& cdinfo) {
    // how does it get the device?
    status_t rc = gConfigureGlobals();
    if (rc != B_NO_ERROR) {
        char err[255];
        sprintf(err, "Error while accessing the CD drive: %s.", 
                strerror(rc));
        ReportError(err);

        return false;
    }

    scsi_toc toc;

    rc = ioctl(gCDPlayerDevice, B_SCSI_GET_TOC, &toc);

    if (rc != B_NO_ERROR) {
        char err[255];
        sprintf(err, "Error while accessing %s: %s.", 
                gCDPlayerDeviceName.String(), strerror(rc));
        ReportError(err);

        return false;
    }	

    /*

      typedef struct {
          byte FirstTrack;         // The first track on CD : normally 1
          byte LastTrack;          // The last track on CD: max number 99
        
          dword FrameOffset[100];  // Track 2 is TrackFrameOffset[2] etc.

          // Leadout Track will be TrackFrameOffset[0]
	
      } MUSICBRAINZ_CDINFO, *PMUSICBRAINZ_CDINFO; 

    */
	

    /*

      SCSI toc format

        http://www.symbios.com/t10
        
        All multibyte values big-endian
        
        uint16 data_length;  // of following data, not including these 2 bytes
        uint8  first_track;
        uint8  last_track;

        struct {
            uint8 reserved;
            uint8 flag_bits; // ADR and CONTROL, whatever
            uint8 track_number;
            uint8 reserved2;
            uint32 logical_block_address;
        } [n];

        // where n fills out the data length
    */


    uint16 data_length = * ((uint16*)toc.toc_data);
    data_length = B_BENDIAN_TO_HOST_INT16(data_length);
    data_length += 2; // to include the length itself
	
    cdinfo.FirstTrack = toc.toc_data[2];
    cdinfo.LastTrack = toc.toc_data[3];
    assert(cdinfo.FirstTrack >= 1 && cdinfo.FirstTrack<=99);
    assert(cdinfo.LastTrack >= 1 && cdinfo.LastTrack<=99);

    int indexer = 4;
    while (indexer < data_length) {
        indexer+=2;
        int track_number = toc.toc_data[indexer];
        indexer+=2;
        uint32 lba = msf_to_lba(toc.toc_data[indexer+1],toc.toc_data[indexer+2],toc.toc_data[indexer+3]);
					
        indexer+=4;

        assert(track_number == 0xaa || (track_number>=1 && track_number <= cdinfo.LastTrack));
        if (track_number == 0xaa)
            track_number = 0;
		
        cdinfo.FrameOffset[track_number] = lba + 150;
    }

    return true;
}


static bool try_dir(const char *directory)
{ 
    BDirectory dir; 
    dir.SetTo(directory); 
    if(dir.InitCheck() != B_NO_ERROR) { 
        return false;
    } 
    dir.Rewind(); 
    BEntry entry; 
    while(dir.GetNextEntry(&entry) >= 0) { 
        BPath path; 
        const char *name; 
        entry_ref e; 
		
        if(entry.GetPath(&path) != B_NO_ERROR) 
            continue; 
        name = path.Path(); 
		
		
        if(entry.GetRef(&e) != B_NO_ERROR) 
            continue; 

        if(entry.IsDirectory()) { 
            if(strcmp(e.name, "floppy") == 0) 
                continue; // ignore floppy (it is not silent) 
            if (try_dir(name))
                return true;
        } 
        else { 
            int devfd; 
            device_geometry g; 

            if(strcmp(e.name, "raw") != 0) 
                continue; // ignore partitions 

            devfd = open(name, O_RDONLY); 
            if(devfd < 0) 
                continue; 

            if(ioctl(devfd, B_GET_GEOMETRY, &g, sizeof(g)) >= 0) {
                if(g.device_type == B_CD)
                    { 
                        gCDPlayerDevice = devfd;
                        gCDPlayerDeviceName = name;
                        return true;
                    }
            }
            close(devfd);
        } 
    }

    return false;
}


static void FindCDPlayerDevice()
{
    try_dir("/dev/disk");
}


static uint32 msf_to_lba(uint8 m, uint8 s, uint8 f) 
{ 
    return (((m * 60) + s) * 75 + f) - 150; 
}
