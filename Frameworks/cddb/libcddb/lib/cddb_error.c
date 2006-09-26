/*
    $Id: cddb_error.c,v 1.12 2005/05/29 08:19:09 airborne Exp $

    Copyright (C) 2003, 2004, 2005 Kris Verbeeck <airborne@advalvas.be>

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


static const char* err_str[CDDB_ERR_LAST] = {
    /* CDDB_ERR_OK */
    "ok",

    /* CDDB_ERR_OUT_OF_MEMORY */
    "out of memory",
    /* CDDB_ERR_LINE_SIZE */
    "internal buffer too small",
    /* CDDB_ERR_NOT_IMPLEMENTED */
    "feature not implemented",
    /* CDDB_ERR_UNKNOWN */
    "problem unknown",

    /* CDDB_ERR_SERVER_ERROR */
    "server error",
    /* CDDB_ERR_UNKNOWN_HOST_NAME */
    "unknown host name",
    /* CDDB_ERR_CONNECT */
    "connection error",
    /* CDDB_ERR_PERMISSION_DENIED */
    "permission denied",
    /* CDDB_ERR_NOT_CONNECTED */
    "not connected",

    /* CDDB_ERR_UNEXPECTED_EOF */
    "unexpected end-of-file",
    /* CDDB_ERR_INVALID_RESPONSE */
    "invalid response data",
    /* CDDB_ERR_DISC_NOT_FOUND */
    "disc not found",

    /* CDDN_ERR_DATA_MISSING */
    "command data missing",
    /* CDDB_ERR_TRACK_NOT_FOUND */
    "track not found",
    /* CDDB_ERR_REJECTED */
    "posted data rejected",
    
    /* CDDB_ERR_EMAIL_INVALID */
    "submit e-mail address invalid",

    /* CDDB_ERR_INVALID_CHARSET */
    "invalid character set or unsupported conversion",
    /* CDDB_ERR_ICONV_FAIL */
    "character set conversion failed",

    /* CDDB_ERR_PROXY_AUTH */
    "proxy authentication failed",
    /* CDDB_ERR_INVALID */
    "invalid input parameter"

    /** CDDB_ERR_LAST */
};

const char *cddb_error_str(cddb_error_t errnum)
{
    if ((errnum < 0) || (errnum >= CDDB_ERR_LAST)) {
        return NULL;
    } else {
        return  err_str[errnum];
    }
}

void cddb_error_stream_print(FILE *stream, cddb_error_t errnum)
{
    fprintf(stream, "libcddb: error: %s\n", cddb_error_str(errnum));
}

void cddb_error_print(cddb_error_t errnum)
{
    cddb_error_stream_print(stderr, errnum);
}
