/*
    $Id: cddb_util.c,v 1.6 2005/04/22 21:43:23 airborne Exp $

    Copyright (C) 2004, 2005 Kris Verbeeck <airborne@advalvas.be>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the
    Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA  02111-1307, USA.
*/

#include "cddb/cddb_ni.h"

#ifdef HAVE_ERRNO_H
#include <errno.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif


int cddb_str_iconv(iconv_t cd, ICONV_CONST char *in, char **out)
{
#ifdef HAVE_ICONV_H
    int inlen, outlen, buflen, rc;
    int len;                    /* number of chars in buffer */
    char *buf;

    inlen = strlen(in);
    buflen = 0;
    buf = NULL;
    do {
        outlen = inlen * 2;
        buflen += outlen;
        /* iconv() below changes the buf pointer:
         * - decrement to point at beginning of buffer before realloc
         * - re-increment to point at first free position after realloc
         */
        len = buflen - outlen;
        buf = (char*)realloc(buf - len, buflen) + len;
        if (buf == NULL) {
            /* XXX: report out of memory error */
            return FALSE;
        }
        rc = iconv(cd, &in, &inlen, &buf, &outlen);
        if ((rc == -1) && (errno != E2BIG)) {
            free(buf);
            return FALSE;       /* conversion failed */
        }
    } while (inlen != 0);
    len = buflen - outlen;
    buf -= len;                 /* reposition at begin of buffer */
    /* make a copy just big enough for the result */
    *out = malloc(len + 1);
    memcpy(*out, buf, len);
    *(*out + len) = '\0';
    free(buf);
#endif
    return TRUE;
}

/* Base64 decoder ring */
static char b64_vec[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

/* This routine will not check for buffer overflows.  Make sure the
 * output buffer is big enough.
 */
void cddb_b64_encode(char *dst, const char *src)
{
    unsigned int triplet = 0;
    int i = 0;

    while (*src) {
        triplet = (triplet << 8) | *src++;
        i++;
        if (i < 3) {
            continue;
        }
        *dst++ = b64_vec[(triplet >> 18)];
        *dst++ = b64_vec[(triplet >> 12) & 0x3f];
        *dst++ = b64_vec[(triplet >>  6) & 0x3f];
        *dst++ = b64_vec[(triplet >>  0) & 0x3f];
        i = 0;
        triplet = 0;
    }
    switch (i) {
    case 1:
        *dst++ = b64_vec[(triplet >> 2)];
        *dst++ = b64_vec[(triplet << 4) & 0x3f];
        *(unsigned short *)dst = 0x3d3d; /* add == */
        dst += 2;
        break;
    case 2:
        *dst++ = b64_vec[(triplet >> 10)];
        *dst++ = b64_vec[(triplet >>  4) & 0x3f];
        *dst++ = b64_vec[(triplet <<  2) & 0x3f];
        *dst++ = '=';
        break;
    }
    *dst = '\0';
}
