/* ------------------------------------------------------------------

   libofa -- the Open Fingerprint Architecture library

   Copyright (C) 2006 MusicIP Corporation
   All rights reserved.

-------------------------------------------------------------------*/
#ifndef _OFA_H_
#define _OFA_H_

#ifdef __cplusplus
extern "C"
{
#endif

#define OFA_LITTLE_ENDIAN (0)
#define OFA_BIG_ENDIAN (1)

/* Retrieve the version of the library */
void ofa_get_version(int *major, int *minor, int *rev);

/* This is the simplest interface required to generate fingerprints.
   examples/protocol.h defines some higher level classes which can be connected
   to codecs in various formats for a higher level API */
const char *ofa_create_print(unsigned char* samples, int byteOrder, long size, int sRate, int stereo);

#ifdef __cplusplus
}
#endif

#endif
