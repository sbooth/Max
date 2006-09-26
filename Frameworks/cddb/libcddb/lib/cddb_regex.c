/*
    $Id: cddb_regex.c,v 1.15 2005/07/23 07:23:24 airborne Exp $

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

#ifdef HAVE_REGEX_H
#include <stdlib.h>
#include <string.h>
#include "cddb/cddb_regex.h"


regex_t *REGEX_TRACK_FRAME_OFFSETS = NULL;
regex_t *REGEX_TRACK_FRAME_OFFSET = NULL;
regex_t *REGEX_DISC_LENGTH = NULL;
regex_t *REGEX_DISC_TITLE = NULL;
regex_t *REGEX_DISC_YEAR = NULL;
regex_t *REGEX_DISC_GENRE = NULL;
regex_t *REGEX_DISC_EXT = NULL;
regex_t *REGEX_TRACK_TITLE = NULL;
regex_t *REGEX_TRACK_EXT = NULL;
regex_t *REGEX_PLAY_ORDER = NULL;
regex_t *REGEX_QUERY_MATCH = NULL;
regex_t *REGEX_SITE = NULL;
regex_t *REGEX_TEXT_SEARCH = NULL;


static int cddb_regex_init_1(regex_t **p, const char *regex)
{
    if ((*p = (regex_t*)malloc(sizeof(regex_t))) == NULL) {
        // XXX: check memory alloc
        return -1;
    }
    return regcomp(*p, regex, REG_EXTENDED);
}


void cddb_regex_init()
{
    int rv;

    rv = cddb_regex_init_1(&REGEX_TRACK_FRAME_OFFSETS,
                           "^#[[:blank:]]*Track frame offsets:[[:blank:]]*$");
    rv = cddb_regex_init_1(&REGEX_TRACK_FRAME_OFFSET,
                           "^#[[:blank:]]*([0-9]+)[[:blank:]]*$");
    rv = cddb_regex_init_1(&REGEX_DISC_LENGTH,
                           "^#[[:blank:]]*Disc length:[[:blank:]]+([0-9]+)( seconds)*[[:blank:]]*$");
    rv = cddb_regex_init_1(&REGEX_DISC_TITLE,
                           "^DTITLE=((.*) / (.*)|(.*))$");
    rv = cddb_regex_init_1(&REGEX_DISC_YEAR,
                           "^DYEAR=([0-9]*)$");
    rv = cddb_regex_init_1(&REGEX_DISC_GENRE,
                           "^DGENRE=(.*)$");
    rv = cddb_regex_init_1(&REGEX_DISC_EXT,
                           "^EXTD=(.*)$");
    rv = cddb_regex_init_1(&REGEX_TRACK_TITLE,
                           "^TTITLE([0-9]+)=((.*) / (.*)|(.*))$");
    rv = cddb_regex_init_1(&REGEX_TRACK_EXT,
                           "^EXTT([0-9]+)=(.*)$");
    rv = cddb_regex_init_1(&REGEX_PLAY_ORDER,
                           "^PLAYORDER=(.*)$");
    rv = cddb_regex_init_1(&REGEX_QUERY_MATCH,
                           "^([[:alpha:]]+)[[:blank:]]([[:xdigit:]]+)[[:blank:]]((.*) / (.*)|(.*))$");

	/* example: freedb.freedb.org cddbp 8880 - N000.00 W000.00 Random freedb server */
    /*          <server> <proto> <port> <query-url> <latitude> <longitude> <description> */
    rv = cddb_regex_init_1(&REGEX_SITE,
                           "^([[:graph:]]+)[[:blank:]]([[:alpha:]]+)[[:blank:]]([[:digit:]]+)[[:blank:]]([[:graph:]]+)[[:blank:]]([NS])([0-9.]+)[[:blank:]]([EW])([0-9.]+)[[:blank:]](.*)$");

    /* example: ...<a href="http://www.freedb.org/freedb_search_fmt.php?cat=rock&id=8e0eee0b">Massive Attack / Mezzanine</a>... */
    /*          ...<a href="http://www.freedb.org/freedb_search_fmt.php?cat=soundtrack&id=b30ed30b"><font size=-1>3</font></a>... */
    /*          <1:greedy_remains> <2:category> <3:discid> <6:artist> <7:title> <8:artist_title> <10:duplicate_number> */
    rv = cddb_regex_init_1(&REGEX_TEXT_SEARCH,
                           "^(.*)/freedb_search_fmt\\.php\\?cat=([[:alpha:]]+)&id=([[:xdigit:]]+)\">"
                           "((([^<]+) / ([^<]+))|([^<]+)|([^>]*>([[:digit:]]+)<.*))</a>.*$");
}

static inline void cddb_regfree(regex_t *regex) 
{
    if (regex) {
        regfree(regex);
        free(regex);
        regex = NULL;
    }
}

void cddb_regex_destroy()
{
    cddb_regfree(REGEX_TRACK_FRAME_OFFSETS);
    cddb_regfree(REGEX_TRACK_FRAME_OFFSET);
    cddb_regfree(REGEX_DISC_LENGTH);
    cddb_regfree(REGEX_DISC_TITLE);
    cddb_regfree(REGEX_DISC_YEAR);
    cddb_regfree(REGEX_DISC_GENRE);
    cddb_regfree(REGEX_DISC_EXT);
    cddb_regfree(REGEX_TRACK_TITLE);
    cddb_regfree(REGEX_TRACK_EXT);
    cddb_regfree(REGEX_PLAY_ORDER);
    cddb_regfree(REGEX_QUERY_MATCH);
    cddb_regfree(REGEX_SITE);
    cddb_regfree(REGEX_TEXT_SEARCH);
}

int cddb_regex_get_int(const char *s, regmatch_t matches[], int idx)
{
    char *buf;
    int i;

    buf = cddb_regex_get_string(s, matches, idx);
    i = atoi(buf);
    free(buf);
    return i;
}

unsigned long cddb_regex_get_hex(const char *s, regmatch_t matches[], int idx)
{
    char *buf, *endp;
    long long h;

    buf = cddb_regex_get_string(s, matches, idx);
    h = strtoll(buf, &endp, 16);
    free(buf);
    return (unsigned long)(h & 0xffffffff);
}

double cddb_regex_get_float(const char *s, regmatch_t matches[], int idx)
{
    char *buf;
    double f;

    buf = cddb_regex_get_string(s, matches, idx);
    f = atof(buf);
    free(buf);
    return f;
}

char *cddb_regex_get_string(const char *s, regmatch_t matches[], int idx)
{
    char *result;
    int start, end, len;

    start = matches[idx].rm_so;
    end = matches[idx].rm_eo;
    len = end - start;
    result = malloc(len + 1);
    strncpy(result, s + start, len);
    result[len] = '\0';
    return result;
}


#endif /*HAVE_REGEX_H*/
