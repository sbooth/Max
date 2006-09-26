/*
    $Id: do_search.c,v 1.2 2005/07/23 07:10:57 airborne Exp $

    Copyright (C) 2005 Kris Verbeeck <airborne@advalvas.be>

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


void do_search(cddb_conn_t *conn, cddb_disc_t *disc, const char *str, int quiet)
{
    int matches, i;

    /* Try searching the database for any discs matching the provided
       search string.  This function will return the number of matches
       that were found.  A return value of 0 means that no matches
       were found.  The data of the first match (when found) will be
       filled in into the disc structure passed to it. */
    matches = cddb_search(conn, disc, str);

    /* If an error occured then the return value will be -1 and the
       internal libcddb error number will be set. */
    if (matches == -1) {
        /* Print an explanatory message on stderr.  Other routines are
           available for retrieving the message without printing it or
           printing it on a stream other than stderr. */
        if (!quiet) {
            cddb_error_print(cddb_errno(conn));
        }
        /* Return to calling fucntion. */
        return;
    }

    printf("Number of matches: %d\n", matches);
    /* A CDDB search command will not return all the disc information.
       It will return a subset that can afterwards be used to do a
       CDDB read.  This enables you to first show a pop-up listing the
       found matches before doing further reads for the full data.
       The data that is returned for each match is: the disc CDDB
       category, the disc ID as known by the server, the disc title
       and the artist's name. */

    /* Let's loop over the matches. */
    i = 0;
    while (i < matches) {
        /* Increment the match counter. */
        i++;

        /* Print out the information for the current match. */
        printf("Match %d\n", i);
        /* Retrieve and print the category and disc ID. */
        printf("  category: %s (%d)\t%08x\n", cddb_disc_get_category_str(disc),
               cddb_disc_get_category(disc), cddb_disc_get_discid(disc));
        /* Retrieve and print the disc title and artist name. */
        printf("  '%s' by %s\n", cddb_disc_get_title(disc),
               cddb_disc_get_artist(disc));

        /* Get the next match, if there is one left. */
        if (i < matches) {
            /* If there are multiple matches, then you can use the
               following function to retrieve the matches beyond the
               first.  This function will overwrite any data that
               might be present in the disc structure passed to it.
               So if you still need that disc for anything else, then
               first create a new disc and use that to call this
               function.  If there are no more matches left, false
               (i.e. 0) will be returned. */
            if (!cddb_search_next(conn, disc)) {
                error_exit(cddb_errno(conn), "query index out of bounds");
            }
        }
    }
}
