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

     $Id: mb_cygwin.h 311 2000-09-22 14:15:03Z robert $

----------------------------------------------------------------------------*/

#if !defined(_CDI_CYGWIN_H_)
#define _CDI_CYGWIN_H_


#define OS "Cygwin"



//
//  Cygwin CD audio declarations
//

// Windows  multimedia stuff

#define MCI_OPEN                        0x0803
#define MCI_CLOSE                       0x0804
#define MCI_SET                         0x080D
#define MCI_STATUS                      0x0814

#define MCI_OPEN_TYPE_ID                0x00001000L
#define MCI_OPEN_TYPE                   0x00002000L
#define MCI_TRACK                       0x00000010L
#define MCI_SET_TIME_FORMAT             0x00000400L

#define MCI_DEVTYPE_CD_AUDIO            516

#define MCI_FORMAT_MSF                  2
#define MCI_FORMAT_FRAMES               3
#define MCI_FORMAT_BYTES                8

#define MCI_STATUS_ITEM                 0x00000100L
#define MCI_STATUS_LENGTH               0x00000001L
#define MCI_STATUS_POSITION             0x00000002L
#define MCI_STATUS_NUMBER_OF_TRACKS     0x00000003L


typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned int DWORD;
typedef unsigned int UINT;
typedef unsigned long LONG;

typedef wchar_t WCHAR;
typedef const char* LPCSTR;
typedef const WCHAR *LPCWSTR;
typedef void* LPVOID;
typedef char* LPSTR;

typedef UINT MCIDEVICEID;


typedef struct tagMCI_OPEN_PARMSA {
    DWORD dwCallback;
    MCIDEVICEID wDeviceID;
    LPCSTR lpstrDeviceType;
    LPCSTR lpstrElementName;
    LPCSTR lpstrAlias;
} MCI_OPEN_PARMSA, *PMCI_OPEN_PARMSA, *LPMCI_OPEN_PARMSA;

typedef struct tagMCI_OPEN_PARMSW {
    DWORD   dwCallback;
    MCIDEVICEID wDeviceID;
    LPCWSTR    lpstrDeviceType;
    LPCWSTR    lpstrElementName;
    LPCWSTR    lpstrAlias;
} MCI_OPEN_PARMSW, *PMCI_OPEN_PARMSW, *LPMCI_OPEN_PARMSW;


#ifdef UNICODE
typedef MCI_OPEN_PARMSW MCI_OPEN_PARMS;
#define mciSendCommand  mciSendCommandW
#definedef ShellExecute ShellExecuteW
#else
typedef MCI_OPEN_PARMSA MCI_OPEN_PARMS;
#define mciSendCommand  mciSendCommandA
#define ShellExecute ShellExecuteA
#endif

typedef struct {
    DWORD dwCallback;
    DWORD dwTimeFormat;
    DWORD dwAudio;
} MCI_SET_PARMS; //, *PMCI_SET_PARMS;  // , *LPMCI_SET_PARMS;


typedef struct {
    DWORD dwCallback;
    DWORD dwReturn;
    DWORD dwItem;
    DWORD dwTrack;
} MCI_STATUS_PARMS; //, *PMCI_STATUS_PARMS;  //, *LPMCI_STATUS_PARMS;


#define MAKELONG(a, b) \
    ((LONG) (((WORD) (a)) | ((DWORD) ((WORD) (b))) << 16)) 


#define MCI_MSF_MINUTE(msf)             ((BYTE)(msf))
#define MCI_MSF_SECOND(msf)             ((BYTE)(((WORD)(msf)) >> 8))
#define MCI_MSF_FRAME(msf)              ((BYTE)((msf)>>16))

#ifdef i386
#define STDCALL     __attribute__ ((stdcall))
#else
#define STDCALL
#endif
#define WINAPI      STDCALL

typedef void* HANDLE;
typedef HANDLE HINSTANCE;
typedef HANDLE HWND;

extern "C" {
DWORD WINAPI mciSendCommandA(MCIDEVICEID mciId, UINT uMsg, DWORD dwParam1, DWORD dwParam2);
DWORD WINAPI mciSendCommandW(MCIDEVICEID mciId, UINT uMsg, DWORD dwParam1, DWORD dwParam2);

HINSTANCE WINAPI ShellExecuteW(HWND, const LPCWSTR, const LPCWSTR, LPCWSTR, const LPCWSTR, int);
HINSTANCE WINAPI ShellExecuteA(HWND, const char *, const char *, char *, const char *, int);
}


#define SW_SHOW 5



// CD Index stuff

typedef char* MUSICBRAINZ_DEVICE;



//
//  Cygwin specific prototypes
//


int ReadTOCHeader(int fd, 
                  int& first, 
                  int& last);

int ReadTOCEntry(int fd, 
                 int track, 
                 int& lba);

#endif

