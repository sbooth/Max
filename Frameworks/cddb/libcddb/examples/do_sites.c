/*
    $Id: do_sites.c,v 1.2 2005/06/15 16:21:05 airborne Exp $

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

#define STR_OR_NULL(s) ((s) ? s : "(null)")

void do_sites(cddb_conn_t *conn)
{
    int idx = 0;
    const cddb_site_t *site = NULL; /* libcddb site structure */
    float latitude, longitude;
    const char *address, *path, *desc;
    unsigned int port;
    cddb_protocol_t protocol;

    /* 1. Instruct libcddb to query the active server for a list of
       mirror sites. */
    if (!cddb_sites(conn)) {
        error_exit(cddb_errno(conn), "could not read sites data");
    }

    /* 2. The sites.  Iterating over the sites retrieved by the
       previous function is done through the use of the
       cddb_first_site and cddb_next_site functions as shown below.
       The end of the list is reached when either function returns a
       NULL pointer.  We start by selecting the first site in the
       list. */
    site = cddb_first_site(conn);
    while (site) {
        /* Except for the protocol getter function, all getters return
           a cddb_error_t value.  This can either be CDDB_ERROR_OK if
           the retrieval of the parameter(s) was successful or
           CDDB_ERR_INVALID if one or more of the input parameters
           were invalid.  No error checking is performed in the code
           below to improve readability. */
        cddb_site_get_address(site, &address, &port);
        /* Failing to get the protocol is signalled by a return value
           of PROTO_UNKNOWN. */
        protocol = cddb_site_get_protocol(site);
        cddb_site_get_query_path(site, &path);
        cddb_site_get_description(site, &desc);
        cddb_site_get_location(site, &latitude, &longitude);
        idx++;
        printf("Mirror %d\n", idx);
        printf("  address:     ");
        if (protocol == PROTO_HTTP) { 
            printf("http://%s:%d%s\n", address, port, path);
        } else if (protocol == PROTO_CDDBP) { 
            printf("%s:%d\n", address, port);
        } else {
            printf("<unknown protocol>\n");
        }
        printf("  description: %s\n", desc);
        printf("  location:    %-7.2f %-7.2f\n", latitude, longitude);
        /* 3. Select next site in the list. */
        site = cddb_next_site(conn);
    }
}
