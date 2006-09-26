/*
    $Id: main.h,v 1.14 2005/07/23 07:19:09 airborne Exp $

    Copyright (C) 2003, 2004, 2005 Kris Verbeeck <airborne@advalvas.be>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <cddb/cddb.h>

/* generic error code */
#define GENERIC_ERROR -1

/* free pointer when it's pointing at something */
#define FREE_NOT_NULL(p) if (p) { free(p); p = NULL; }

/**
 * Prints out an error string and exits the program with the provided
 * error code.
 *
 * @param err Error code.
 * @param fmt A printf style format string.
 */
void error_exit(int err, const char *fmt, ...);

void do_query(cddb_conn_t *conn, cddb_disc_t *disc, int quiet);

cddb_disc_t *do_read(cddb_conn_t *conn, const char *category, int discid, int quiet);

void do_display(cddb_disc_t *disc);

cddb_disc_t *cd_read(char *device);

cddb_disc_t *cd_create(int dlength, int tcount, int *foffset, int use_time);

void do_sites(cddb_conn_t *conn);

void do_search(cddb_conn_t *conn, cddb_disc_t *disc, const char *str, int quiet);
