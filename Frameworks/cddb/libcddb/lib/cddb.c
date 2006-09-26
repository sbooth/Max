/*
    $Id: cddb.c,v 1.2 2005/07/17 09:53:49 airborne Exp $

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


/* --- global variables */


cddb_conn_t *cddb_search_conn;

/** Library initialized or not? */
static int initialized = 0;


/* --- public functions */


void libcddb_init(void)
{
    if (!initialized) {
        cddb_regex_init();
        initialized = 1;        /* before the call to cddb_new() below to avoid
                                   deadlock */
        /* Initialize connection structure for text search */
        cddb_search_conn = cddb_new();
        cddb_http_enable(cddb_search_conn);
        cddb_set_server_port(cddb_search_conn, 80);
        cddb_set_http_path_query(cddb_search_conn, "/freedb_search.php");
    }
}

void libcddb_shutdown(void)
{
    if (initialized) {
        cddb_regex_destroy();
        cddb_destroy(cddb_search_conn);
        initialized = 0;
    }
}
