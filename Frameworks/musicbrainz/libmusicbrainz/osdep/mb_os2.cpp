/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1998 Jukka Poikolainen
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

     $Id: mb_os2.cpp 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/

#include <os2mm.h>
#include <stdio.h>
#include <memory.h>
#include <shellapi.h>

#include "diskid.h"

MUSICBRAINZ_DEVICE DEFAULT_DEVICE = "0";


int ReadTOCHeader(int fd, 
                  int& first, 
                  int& last)
{
    return 0;
}


int ReadTOCEntry(int fd, 
                 int track, 
                 int& lba)
{
    return 0;
}


bool DiskId::ReadTOC(MUSICBRAINZ_DEVICE device, 
                     MUSICBRAINZ_CDINFO& cdinfo)
{
    UINT wDeviceID;
    DWORD i;
    MCI_OPEN_PARMS mciOpenParms;
    MCI_SET_PARMS mciSetParms;
    char err[256];

    MCI_STATUS_PARMS mciStatusParms;

    memset(&cdinfo, 0, sizeof(cdinfo));

    if (device == NULL) {
        mciOpenParms.lpstrDeviceType = "cdaudio";

        if (mciSendCommand(NULL, 
                           MCI_OPEN, 
                           MCI_OPEN_TYPE, 
                           (DWORD)(LPVOID) &mciOpenParms))	
            ReportError("Cannot open cdaudio device.");
            return false;    
    }
    else {
        mciOpenParms.lpstrDeviceType = (LPSTR) MAKELONG(MCI_DEVTYPE_CD_AUDIO, atoi(device));

        if (mciSendCommand(NULL, 
                           MCI_OPEN, 
                           MCI_OPEN_TYPE_ID | MCI_OPEN_TYPE, 
                           (DWORD)(LPVOID) &mciOpenParms)) {
            sprintf(err, "Cannot open device id %d.", atoi(device));
            ReportError(err);
            return false;    
        }
    }

    wDeviceID = mciOpenParms.wDeviceID;

    mciSetParms.dwTimeFormat = MCI_FORMAT_MSF;

    if (mciSendCommand(wDeviceID, 
                       MCI_SET, 
                       MCI_SET_TIME_FORMAT, 
                       (DWORD)(LPVOID) &mciSetParms)) {
        mciSendCommand(wDeviceID, 
                       MCI_CLOSE, 
                       0, 
                       NULL);
        ReportError("Cannot set time format for cd drive.");
        return false;
    }
    
    mciStatusParms.dwItem = MCI_STATUS_NUMBER_OF_TRACKS;

    if (mciSendCommand(wDeviceID, 
                       MCI_STATUS, 
                       MCI_STATUS_ITEM, 
                       (DWORD)(LPVOID) &mciStatusParms)) {        

        mciSendCommand(wDeviceID, 
                       MCI_CLOSE, 
                       0, 
                       NULL);		
        ReportError("Cannot get the cd drive status.");
        return false;
    }

    cdinfo.FirstTrack = 1;
    cdinfo.LastTrack = (BYTE) mciStatusParms.dwReturn;    	
 
    for(i = 1; i <= cdinfo.LastTrack; i++) {
        mciStatusParms.dwItem = MCI_STATUS_POSITION;
        mciStatusParms.dwTrack = i;
        
        if (mciSendCommand(wDeviceID, 
                           MCI_STATUS, 
                           MCI_STATUS_ITEM | MCI_TRACK, 
                           (DWORD)(LPVOID) &mciStatusParms)) {
            mciSendCommand(wDeviceID, 
                           MCI_CLOSE, 
                           0, 
                           NULL);
            ReportError("Cannot read table of contents.");
            return false;
        }

        cdinfo.FrameOffset[i] = (DWORD) MCI_MSF_MINUTE(mciStatusParms.dwReturn) * 4500 +
                                (DWORD) MCI_MSF_SECOND(mciStatusParms.dwReturn) * 75 +
				(DWORD) MCI_MSF_FRAME(mciStatusParms.dwReturn);
    }   
	
    mciStatusParms.dwItem = MCI_STATUS_LENGTH;
    mciStatusParms.dwTrack = cdinfo.LastTrack;

    if (mciSendCommand(wDeviceID, 
                       MCI_STATUS, 
                       MCI_STATUS_ITEM | MCI_TRACK, 
                       (DWORD) (LPVOID) &mciStatusParms)) {
        mciSendCommand(wDeviceID, 
                       MCI_CLOSE, 
                       0, 
                       NULL);
        ReportError("Cannot read table of contents.");
        return false;
    }

    cdinfo.FrameOffset[0] = cdinfo.FrameOffset[cdinfo.LastTrack] + 
                            (DWORD) MCI_MSF_MINUTE(mciStatusParms.dwReturn) * 4500 +
                            (DWORD) MCI_MSF_SECOND(mciStatusParms.dwReturn) * 75 +
                            (DWORD) MCI_MSF_FRAME(mciStatusParms.dwReturn) + 1;				
    mciSendCommand(wDeviceID, 
                   MCI_CLOSE, 
                   0, 
                   NULL);
    return true;
}
