/*
    $Id: cddb_site.c,v 1.3 2005/06/15 16:12:04 airborne Exp $

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


#include "config.h"

#ifdef HAVE_STRING_H
#include <string.h>
#endif

#include "cddb/cddb_ni.h"
#include "cddb/cddb_site.h"


/* --- type and structure definitions */


struct cddb_site_s
{
    char *address;              /**< host name of the CDDB server */
    cddb_protocol_t protocol;   /**< the protocol used by this site */
    int port;                   /**< port of the CDDB server */
    char *query_path;           /**< query path for HTTP URL */
    char *submit_path;          /**< submit path for HTTP URL */
    char *desc;                 /**< server description */
    float latitude;             /**< server latitude */
    float longitude;            /**< server longitude */
};


/* --- private functions */


int cddb_site_iconv(iconv_t cd, cddb_site_t *site)
{ 
    char *result;

    if (!cd) {
        return TRUE;            /* no user character set defined */
    }
    if (site->desc) {
        if (cddb_str_iconv(cd, site->desc, &result)) {
            free(site->desc);
            site->desc = result;
        } else {
            return FALSE;
        }
    }
    return TRUE;
}


/* --- construction / destruction */


cddb_site_t *cddb_site_new(void)
{
    cddb_site_t *site;

    site = (cddb_site_t*)calloc(1, sizeof(cddb_site_t));
    return site;
}

cddb_error_t cddb_site_destroy(cddb_site_t *site)
{
    ASSERT_NOT_NULL(site);
    FREE_NOT_NULL(site->address);
    FREE_NOT_NULL(site->query_path);
    FREE_NOT_NULL(site->submit_path);
    FREE_NOT_NULL(site->desc);
    free(site);
    return CDDB_ERR_OK;
}

cddb_site_t *cddb_site_clone(cddb_site_t *site)
{
    cddb_site_t *clone;

    cddb_log_debug("cddb_site_clone()");
    clone = cddb_site_new();
    clone->address = (site->address ? strdup(site->address) : NULL);
    clone->protocol = site->protocol;
    clone->port = site->port;
    clone->query_path = (site->query_path ? strdup(site->query_path) : NULL);
    clone->submit_path = (site->submit_path ? strdup(site->submit_path) : NULL);
    clone->desc = (site->desc ? strdup(site->desc) : NULL);
    clone->latitude = site->latitude;
    clone->longitude = site->longitude;
    return clone;
}


/* --- setters / getters --- */


cddb_error_t cddb_site_get_address(const cddb_site_t *site,
                                   const char **address, unsigned int *port)
{
    ASSERT_NOT_NULL(site);
    ASSERT_NOT_NULL(address);
    ASSERT_NOT_NULL(port);
    *address = site->address;
    *port = site->port;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_set_address(cddb_site_t *site,
                                   const char *address, unsigned int port)
{
    ASSERT_NOT_NULL(site);
    ASSERT_NOT_NULL(address);
    FREE_NOT_NULL(site->address);
    site->address = strdup(address);
    if (!site->address) {
        return CDDB_ERR_OUT_OF_MEMORY;
    }
    site->port = port;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_get_location(const cddb_site_t *site,
                                    float *latitude, float *longitude)
{
    ASSERT_NOT_NULL(site);
    ASSERT_NOT_NULL(latitude);
    ASSERT_NOT_NULL(longitude);
    *latitude = site->latitude;
    *longitude = site->longitude;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_set_location(cddb_site_t *site,
                                    float latitude, float longitude)
{
    ASSERT_NOT_NULL(site);
    ASSERT_RANGE(latitude, -90.0, 90.0);
    ASSERT_RANGE(longitude, -180.0, 180.0);
    site->latitude = latitude;
    site->longitude = longitude;
    return CDDB_ERR_OK;
}

cddb_protocol_t cddb_site_get_protocol(const cddb_site_t *site)
{
    if (site) {
        return site->protocol;
    }
    return PROTO_UNKNOWN;
}

cddb_error_t cddb_site_set_protocol(cddb_site_t *site, cddb_protocol_t proto)
{
    ASSERT_NOT_NULL(site);
    site->protocol = proto;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_get_query_path(const cddb_site_t *site,
                                      const char **path)
{
    ASSERT_NOT_NULL(site);
    ASSERT_NOT_NULL(path);
    *path = site->query_path;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_set_query_path(cddb_site_t *site, const char *path)
{
    ASSERT_NOT_NULL(site);
    FREE_NOT_NULL(site->query_path);
    if (path) {
        site->query_path = strdup(path);
        if (!site->query_path) {
            return CDDB_ERR_OUT_OF_MEMORY;
        }
    }
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_get_submit_path(const cddb_site_t *site,
                                       const char **path)
{
    ASSERT_NOT_NULL(site);
    ASSERT_NOT_NULL(path);
    *path = site->submit_path;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_set_submit_path(cddb_site_t *site, const char *path)
{
    ASSERT_NOT_NULL(site);
    FREE_NOT_NULL(site->submit_path);
    if (path) {
        site->submit_path = strdup(path);
        if (!site->submit_path) {
            return CDDB_ERR_OUT_OF_MEMORY;
        }
    }
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_get_description(const cddb_site_t *site,
                                       const char **desc)
{
    ASSERT_NOT_NULL(site);
    ASSERT_NOT_NULL(desc);
    *desc = site->desc;
    return CDDB_ERR_OK;
}

cddb_error_t cddb_site_set_description(cddb_site_t *site, const char *desc)
{
    ASSERT_NOT_NULL(site);
    FREE_NOT_NULL(site->desc);
    if (desc) {
        site->desc = strdup(desc);
        if (!site->desc) {
            return CDDB_ERR_OUT_OF_MEMORY;
        }
    }
    return CDDB_ERR_OK;
}


/* --- miscellaneous */


int cddb_site_parse(cddb_site_t *site, const char *line)
{
    regmatch_t matches[10];
    char *s;
    float f;

    if (regexec(REGEX_SITE, line, 10, matches, 0) == REG_NOMATCH) {
        /* invalid repsponse */
        return FALSE;
    }
    site->address = cddb_regex_get_string(line, matches, 1);
    s = cddb_regex_get_string(line, matches, 2);
    if (strcmp(s, "cddbp") == 0) {
        site->protocol = PROTO_CDDBP;
    } else if (strcmp(s, "http") == 0) {
        site->protocol = PROTO_HTTP;
    } else {
        site->protocol = PROTO_UNKNOWN;
    }
    site->port = cddb_regex_get_int(line, matches, 3);
    site->query_path = cddb_regex_get_string(line, matches, 4);
    s = cddb_regex_get_string(line, matches, 5);
    f = cddb_regex_get_float(line, matches, 6);
    if (*s == 'N') {
        site->latitude = f;
    } else if (*s == 'S') {
        site->latitude = -f;
    } else {
        site->latitude = 0.0;
    }
    free(s);
    s = cddb_regex_get_string(line, matches, 7);
    f = cddb_regex_get_float(line, matches, 8);
    if (*s == 'E') {
        site->longitude = f;
    } else if (*s == 'W') {
        site->longitude = -f;
    } else {
        site->longitude = 0.0;
    }
    free(s);
    site->desc = cddb_regex_get_string(line, matches, 9);
    return TRUE;
}

cddb_error_t cddb_site_print(const cddb_site_t *site)
{
    ASSERT_NOT_NULL(site);
    printf("Address: ");
    if (site->protocol == PROTO_CDDBP) {
        printf("%s:%d\n", site->address, site->port);
    } else if (site->protocol == PROTO_HTTP) {
        printf("http://%s:%d%s\n", site->address, site->port, site->query_path);
    }
    printf("Description: %s\n", site->desc);
    printf("Location: %4.2f %4.2f\n", site->latitude, site->longitude);
    return CDDB_ERR_OK;    
}
