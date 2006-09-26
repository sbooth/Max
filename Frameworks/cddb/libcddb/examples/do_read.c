/*
    $Id: do_read.c,v 1.8 2005/03/11 21:29:27 airborne Exp $

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

#include "main.h"


cddb_disc_t *do_read(cddb_conn_t *conn, const char *category, int discid, int quiet)
{
    cddb_disc_t *disc = NULL;   /* libcddb disc structure */
    int success;

    /* Create a new disc structure. */
    disc = cddb_disc_new();

    /* If the pointer is NULL then an error occured (out of memory).
       Otherwise we continue. */
    if (disc) {
        /* Initialize the category of the disc.  This function
           converts a string into a category ID as used by libcddb.
           If the specified string does not match any of the known
           categories, then the category is set to 'misc'. */
        cddb_disc_set_category_str(disc, category);

        /* Initialize the ID of the disc. */
        cddb_disc_set_discid(disc, discid);

        /* Try reading the rest of the disc data.  This information
           will be retrieved from the server or read from the cache
           depending on the connection settings. */
        success = cddb_read(conn, disc);

        /* If an error occured then the return value will be false and the
           internal libcddb error number will be set. */
        if (!success) {
            /* Print an explanatory message on stderr.  Other routines are
               available for retrieving the message without printing it or
               printing it on a stream other than stderr. */
            if (!quiet) {
                cddb_error_print(cddb_errno(conn));
            }
            /* Destroy the disc. */
            cddb_disc_destroy(disc);
            /* And return NULL to signal an error. */
            return NULL;
        }
    }

    return disc;
}
