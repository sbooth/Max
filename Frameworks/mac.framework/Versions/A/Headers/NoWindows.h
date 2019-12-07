#pragma once

#if !defined(PLATFORM_WINDOWS)

// we treat bool as a global type, so don't declare it in the namespace
#ifdef PLATFORM_APPLE
	typedef signed char BOOL;  // this is the way it's defined in Obj-C
#else
	typedef unsigned char BOOL; // this is the way it's defined in X11
#endif

namespace APE
{

#define NEAR
#define FAR

typedef unsigned long       DWORD;
typedef unsigned char       BYTE;
typedef unsigned short      WORD;
typedef float               FLOAT;
typedef void *              HANDLE;
typedef unsigned int        UINT;
//typedef unsigned int        intn;
//typedef long                intn;
typedef const char *        LPCSTR;
typedef char *              LPSTR;
typedef long                LRESULT;

#define ZeroMemory(POINTER, BYTES) memset(POINTER, 0, BYTES);

#define __stdcall
#define CALLBACK

#define _T(x) L ## x

#define _strnicmp strncasecmp
#define _wtoi(x) wcstol(x, NULL, 10)
#define _tcscat wcscat
#define _totlower towlower
#define _totupper towupper

#ifdef PLATFORM_LINUX
#define _FPOSOFF(fp) (fp.__pos)
#else
#define _FPOSOFF(fp) (fp)
#endif
#define MAX_PATH    4096

}

#endif // #ifndef _WIN32
