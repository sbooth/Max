/*
    $Id: do_display.c,v 1.8 2005/07/09 08:25:10 airborne Exp $

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

#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h> /* strlen */
#endif

#define STR_OR_NULL(s) ((s) ? s : "(null)")

void do_display(cddb_disc_t *disc)
{
    cddb_track_t *track = NULL; /* libcddb track structure */
    int length;
    const char *s;

    /* 1. The artist name, disc title and extended data. */
    printf("Artist:   %s\n", STR_OR_NULL(cddb_disc_get_artist(disc)));
    printf("Title:    %s\n", STR_OR_NULL(cddb_disc_get_title(disc)));
    s = cddb_disc_get_ext_data(disc);
    if (s) {
        printf("Ext.data: %s\n", s);
    }

    /* 2. The music genre.  This field is similar to the category
       field initialized above.  It can be the same but it does not
       have to be.  The category can only be come from a set of CDDB
       predefined categories.  The genre can be any string. */
    printf("Genre:    %s\n", STR_OR_NULL(cddb_disc_get_genre(disc)));

    /* 3. The disc year. */
    printf("Year:     %d\n", cddb_disc_get_year(disc));

    /* 4. The disc length and the number of tracks.  The length field
       is given in seconds. */
    length = cddb_disc_get_length(disc);
    printf("Length:   %d:%02d (%d seconds)\n", (length / 60), (length % 60), length);
    printf("%d tracks\n", cddb_disc_get_track_count(disc));

    /* 5. The tracks.  Track iteration can either be done by counting
       from 0 to (track_count - 1) and using the cddb_disc_get_track
       function.  Or by using the built-in iterator functions
       cddb_disc_get_track_first and cddb_disc_get_track_next.  We'll
       use the latter approach in this example. */

    for (track = cddb_disc_get_track_first(disc); 
         track != NULL; 
         track = cddb_disc_get_track_next(disc)) {

        /* 5.a. The track number on the disc.  This track number
           starts counting at 1.  So this is not the same number as
           the one used in cddb_disc_get_track. */
        printf("  [%02d]", cddb_track_get_number(track));

        /* 5.b. The track artist name and title. */
        printf(" '%s' by %s", cddb_track_get_title(track), 
               cddb_track_get_artist(track));

        /* 5.c. The track length. */
        length = cddb_track_get_length(track);
        if (length != -1) {
            printf(" (%d:%02d)", (length / 60), (length % 60));
        } else {
            printf(" (unknown)");
        }

        /* 5.d. The extended track data. */
        s = cddb_track_get_ext_data(track);
        if (s && strlen(s) > 0) {
            printf(" [%s]\n", s);
        } else {
            printf("\n");
        }
    }
}
