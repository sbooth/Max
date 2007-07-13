/* NIST Secure Hash Algorithm */
/* heavily modified by Uwe Hollerbach <uh@alumni.caltech edu> */
/* from Peter C. Gutmann's implementation as found in */
/* Applied Cryptography by Bruce Schneier */
/* This code is in the public domain */
/* $Id: sha1.h 7777 2006-06-01 17:37:15Z matt $ */

#ifndef SHA_H
#define SHA_H

#include <stdlib.h>
#include <stdio.h>

/* Useful defines & typedefs */
typedef unsigned char SHA_BYTE;	/* 8-bit quantity */
typedef unsigned long SHA_LONG;	/* 32-or-more-bit quantity */

#define SHA_BLOCKSIZE		64
#define SHA_DIGESTSIZE		20

typedef struct {
    SHA_LONG digest[5];		/* message digest */
    SHA_LONG count_lo, count_hi;	/* 64-bit bit count */
    SHA_BYTE data[SHA_BLOCKSIZE];	/* SHA data buffer */
    int local;			/* unprocessed amount in data */
} SHA_INFO;

void sha_init(SHA_INFO *);
void sha_update(SHA_INFO *, SHA_BYTE *, int);
void sha_final(unsigned char [20], SHA_INFO *);

void sha_stream(unsigned char [20], SHA_INFO *, FILE *);
void sha_print(unsigned char [20]);
char *sha_version(void);

#define SHA_VERSION 1

#ifdef HAVE_CONFIG_H 
#include "config.h"


#ifdef WORDS_BIGENDIAN
#  if SIZEOF_LONG == 4
#    define SHA_BYTE_ORDER  4321
#  elif SIZEOF_LONG == 8
#    define SHA_BYTE_ORDER  87654321
#  endif
#else
#  if SIZEOF_LONG == 4
#    define SHA_BYTE_ORDER  1234
#  elif SIZEOF_LONG == 8
#    define SHA_BYTE_ORDER  12345678
#  endif
#endif

#else

#define SHA_BYTE_ORDER 1234

#endif

#endif /* SHA_H */
