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

     $Id: diskid.h 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/

#if !defined(_DISKID_H_)
#define _DISKID_H_

#include <string>

using namespace std;

//
//  platform specific stuff
//

#if defined(_WIN32) && !defined(__CYGWIN__)
#include "../osdep/mb_win32.h"  // MSVC++ (not Cygwin!)
#else
#include "mb.h"        // platforms using configure script
#endif
#include "types.h"
#include "errors.h"


//
//  constants
//

#if !defined(CD_BLOCK_OFFSET)
#define CD_BLOCK_OFFSET CD_MSF_OFFSET
#endif



//
//  cdinfo struct 
//

typedef	unsigned char byte;
typedef unsigned long dword;

typedef struct {
    byte FirstTrack;         // The first track on CD : normally 1
    byte LastTrack;          // The last track on CD: max number 99
    
    dword FrameOffset[100];  // Track 2 is TrackFrameOffset[2] etc.
                             // Leadout Track will be TrackFrameOffset[0]

} MUSICBRAINZ_CDINFO, *PMUSICBRAINZ_CDINFO; 


extern MUSICBRAINZ_DEVICE DEFAULT_DEVICE;


//
// DiskId class 
//

class DiskId
{
    public:

                 DiskId(void);
        virtual ~DiskId(void);

        Error GenerateDiskIdRDF(const string &device, string &xml);
        Error GenerateDiskIdQueryRDF(const string &device, string &xml,
                                     bool associateCD);
        Error GetWebSubmitURLArgs(const string &device, string &args);
        void  GetLastError(string &err);

    protected:

        void  TestGenerateId();
        void  GenerateId(PMUSICBRAINZ_CDINFO pCDInfo, char DiscId[33]);
        void  ReportError(char *err);
        Error FillCDInfo(const string &device, MUSICBRAINZ_CDINFO &cdinfo);
        const string &MakeString(int i);

        // This function is OS dependent, and will be implemented by
        // one of the modules in the osdep dir.
        bool ReadTOC(MUSICBRAINZ_DEVICE device, 
                     MUSICBRAINZ_CDINFO& cdinfo);

    private:

        string m_errorMsg;
};

#endif
