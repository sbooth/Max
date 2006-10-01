/*
    $Id: cddb_cmd.c,v 1.62 2006/09/29 15:34:53 airborne Exp $

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

#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "cddb/cddb_ni.h"
#include "cddb/ll.h"


static const char *CDDB_COMMANDS[CMD_LAST] = {
    "cddb hello %s %s %s %s",
    "quit",
    "cddb read %s %08x",
    "cddb query %08x %d %s %d",
    "cddb write %s %08x",
    "proto %d",
    "sites",
    /* special full text search command (only HTTP) */
    "words=%s%s",
};

#define WRITE_BUF_SIZE 4096


/*
 * Small memory cache for querying local database.
 */
#define QUERY_CACHE_SIZE 256
static struct query_cache_entry {
    unsigned int discid;
    cddb_cat_t category;
} query_cache[QUERY_CACHE_SIZE];


/* --- prototypes --- */


/**
 * @return the line read or NULL if something goes wrong
 */
char *cddb_read_line(cddb_conn_t *c);

/**
 * @returns The amount of data written into the buffer.
 */
int cddb_write_data(cddb_conn_t *c, char *buf, int size, cddb_disc_t *disc);

int cddb_http_parse_response(cddb_conn_t *c);

void cddb_http_parse_headers(cddb_conn_t *c);

int cddb_http_send_cmd(cddb_conn_t *c, cddb_cmd_t cmd, va_list args);

int cddb_parse_record(cddb_conn_t *c, cddb_disc_t *disc);

int cddb_parse_query_data(cddb_conn_t *c, cddb_disc_t *disc, const char *line);

static int cddb_parse_search_data(cddb_conn_t *c, cddb_disc_t **disc,
                                  char *line, regmatch_t *matches);

static void cddb_search_param_str(cddb_search_params_t *params,
                                  char *buf, int len);

char *cddb_cache_file_name(cddb_conn_t *c, cddb_disc_t *disc);

int cddb_cache_exists(cddb_conn_t *c, cddb_disc_t *disc);

int cddb_cache_open(cddb_conn_t *c, cddb_disc_t *disc, const char* mode);

void cddb_cache_close(cddb_conn_t *c);

int cddb_cache_read(cddb_conn_t *c, cddb_disc_t *disc);

int cddb_cache_query(cddb_conn_t *c, cddb_disc_t *disc);

int cddb_cache_query_disc(cddb_conn_t *c, cddb_disc_t *disc);

/**
 * Initialize the local query cache.
 */
void cddb_cache_query_init(void);

int cddb_cache_mkdir(cddb_conn_t *c, cddb_disc_t *disc);


/* --- CDDB slave routines --- */


char *cddb_cache_file_name(cddb_conn_t *c, cddb_disc_t *disc)
{
    char *fn = NULL;
    int len;

    /* calculate needed buffer size (+11 for two slashes, disc id and
       terminating zero */
    len = strlen(c->cache_dir) + strlen(CDDB_CATEGORY[disc->category]) + 11;
    /* reserve enough memory */
    fn = (char*)malloc(len + 1);
    /* create file name */
    if (fn) {
        snprintf(fn, len + 1, "%s/%s/%08x", c->cache_dir, 
                 CDDB_CATEGORY[disc->category], disc->discid);
    } else {
        cddb_errno_log_crit(c, CDDB_ERR_OUT_OF_MEMORY);
    }
    return fn;
}

int cddb_cache_exists(cddb_conn_t *c, cddb_disc_t *disc)
{
    int rv = FALSE;
    char *fn = NULL;
    struct stat buf;

    cddb_log_debug("cddb_cache_exists()");
    /* try to stat cache file */
    fn = cddb_cache_file_name(c, disc);
    if (fn) {
        if ((stat(fn, &buf) == -1) || !S_ISREG(buf.st_mode)) {
            cddb_log_debug("...not in cache");
        } else {
            cddb_log_debug("...in cache");
            rv = TRUE;
        }
    }
    FREE_NOT_NULL(fn);
    return rv;
}

int cddb_cache_open(cddb_conn_t *c, cddb_disc_t *disc, const char* mode)
{
    int rv = FALSE;
    char *fn = NULL;

    cddb_log_debug("cddb_cache_open()");
    /* close previous entry */
    cddb_cache_close(c);
    /* open new entry */
    fn = cddb_cache_file_name(c, disc);
    if (fn) {
        c->cache_fp = fopen(fn, mode);
        rv = (c->cache_fp != NULL);
    }
    FREE_NOT_NULL(fn);
    return rv;
}

void cddb_cache_close(cddb_conn_t *c)
{
    if (c->cache_fp != NULL) {
        cddb_log_debug("cddb_cache_close()");
        fclose(c->cache_fp);
        c->cache_fp = NULL;
    }
}

int cddb_cache_read(cddb_conn_t *c, cddb_disc_t *disc)
{
    int rv;

    cddb_log_debug("cddb_cache_read()");
    if (c->use_cache == CACHE_OFF) {
        /* don't use cache */
        cddb_log_debug("...cache disabled");
        return FALSE;
    }

    /* check whether cached version exists */
    if (!cddb_cache_exists(c, disc)) {
        /* no cached version available */
        cddb_log_debug("...no cached version found");
        return FALSE;
    }

    /* try to open cache file */
    if (!cddb_cache_open(c, disc, "r")) {
        /* cached version not readable */
        char *fn = cddb_cache_file_name(c, disc);
        cddb_log_warn("cache file not readable: %s", fn);
        FREE_NOT_NULL(fn);
        return FALSE;
    }

    /* parse CDDB record */
    cddb_log_debug("...cached version found");
    c->cache_read = TRUE;
    rv = cddb_parse_record(c, disc);
    c->cache_read = FALSE;

    /* close cache entry */
    cddb_cache_close(c);

    return rv;
}

void cddb_cache_query_init(void)
{
    static int query_cache_init = FALSE;
    int i;

    if (!query_cache_init) {
        for (i = 0; i < sizeof(QUERY_CACHE_SIZE); i++) {
            query_cache[i].category = CDDB_CAT_INVALID;
        }
        query_cache_init = TRUE;
    }
}

/* use upper 8 bits of disc ID as hash */
#define cddb_cache_query_hash(disc) ((disc)->discid >> 24)

int cddb_cache_query(cddb_conn_t *c, cddb_disc_t *disc)
{
    int hash;

    cddb_log_debug("cddb_cache_query()");
    if (c->use_cache == CACHE_OFF) {
        /* don't use cache */
        cddb_log_debug("...cache disabled");
        return FALSE;
    }

    /* initialize memory cache */
    cddb_cache_query_init();

    /* calculate disc hash */
    hash = cddb_cache_query_hash(disc);

    /* data already in memory? */
    if (query_cache[hash].discid == disc->discid) {
        cddb_log_debug("...entry found in memory");
        disc->category = query_cache[hash].category;
        cddb_errno_set(c, CDDB_ERR_OK);
        return TRUE;
    }

    /* search local database on disc */
    return cddb_cache_query_disc(c, disc);
}

int cddb_cache_query_disc(cddb_conn_t *c, cddb_disc_t *disc)
{
    int cat, hash;

    cddb_log_debug("cddb_cache_query_disc()");
    for (cat = CDDB_CAT_DATA; cat < CDDB_CAT_INVALID; cat++) {
        disc->category = cat;
        if (cddb_cache_exists(c, disc)) {
            /* update memory cache */
            hash = cddb_cache_query_hash(disc);
            query_cache[hash].discid = disc->discid;
            query_cache[hash].category = disc->category;
            cddb_log_debug("...entry found in local db");
            cddb_errno_set(c, CDDB_ERR_OK);
            return TRUE;
        }
    }
    disc->category = CDDB_CAT_INVALID;
    cddb_log_debug("...entry not found in local db");
    return FALSE;
}

#if defined( WIN32 )
#define MKDIR(dir, mode)  mkdir(dir)
#else
#define MKDIR(dir, mode)  mkdir(dir, mode)
#endif 

int cddb_cache_mkdir(cddb_conn_t *c, cddb_disc_t *disc)
{
    char *fn = NULL;

    cddb_log_debug("cddb_cache_mkdir()");
    /* create CDDB slave dir */
    if ((MKDIR(c->cache_dir, 0755) == -1) && (errno != EEXIST)) {
        cddb_log_error("could not create cache directory: %s", c->cache_dir);
        return FALSE;
    }

    /* create category dir */
    fn = (char*)malloc(c->buf_size);
    snprintf(fn, c->buf_size, "%s/%s", c->cache_dir, CDDB_CATEGORY[disc->category]);
    if ((MKDIR(fn, 0755) == -1) && (errno != EEXIST)) {
        cddb_log_error("could not create category directory: %s", fn);
        free(fn);
        return FALSE;
    }
    free(fn);

    return TRUE;
}


/* --- server request / response handling --- */


int cddb_get_response_code(cddb_conn_t *c, char **msg)
{
    char *line, *space;
    int code, rv;

    cddb_log_debug("cddb_get_response_code()");
    line = cddb_read_line(c);
    if (!line) {
        if (cddb_errno(c) != CDDB_ERR_OK) {
            cddb_errno_log_error(c, CDDB_ERR_UNEXPECTED_EOF);
        }
        return -1;
    }

    rv = sscanf(line, "%d", &code);
    if (rv != 1) {
        cddb_errno_log_error(c, CDDB_ERR_INVALID_RESPONSE);
        return -1;
    }

    space = strchr(line, CHR_SPACE);
    if (space == NULL) {
        cddb_errno_log_error(c, CDDB_ERR_INVALID_RESPONSE);
        return -1;
    }
    *msg = space + 1;           /* message starts after space */

    cddb_errno_set(c, CDDB_ERR_OK);
    cddb_log_debug("...code = %d (%s)", code, *msg);
    return code;
}

char *cddb_read_line(cddb_conn_t *c)
{
    char *s;

    cddb_log_debug("cddb_read_line()");
    /* read line, possibly returning NULL */
    if (c->cache_read) {
        s = fgets(c->line, c->buf_size, cddb_cache_file(c));
    } else {
        s = sock_fgets(c->line, c->buf_size, c);
    }

    /* strip off any line-terminating characters */
    if (s) {
        s = s + strlen(s) - 1;
        while ((s >= c->line) && 
               ((*s == CHR_CR) || (*s == CHR_LF))) {
            *s = CHR_EOS;
            s--;
        }
    } else {
        return NULL;
    }

    cddb_errno_set(c, CDDB_ERR_OK);
    cddb_log_debug("...[%c] line = '%s'", (c->cache_read ? 'C' : 'N'), c->line);
    return c->line;
}

static void url_encode(char *s)
{
    while (*s) {
        switch (*s) {
            case ' ': *s = '+'; break;
        }
        s++;
    }
}

int cddb_http_parse_response(cddb_conn_t *c)
{
    char *line;
    int code;

    if ((line = cddb_read_line(c)) == NULL) {
        /* no HTTP response line */
        cddb_errno_log_error(c, CDDB_ERR_UNEXPECTED_EOF);
        return FALSE;
    }

    if (sscanf(line, "%*s %d %*s", &code) != 1) {
        /* invalid */
        cddb_errno_log_error(c, CDDB_ERR_INVALID_RESPONSE);
        return FALSE;
    }

    cddb_log_debug("...HTTP response code = %d", code);
    switch (code) {
        case 200:
            /* HTTP OK */
            break;
        case 407:
            cddb_errno_log_error(c, CDDB_ERR_PROXY_AUTH);
            return FALSE;
            break;
        default:
            /* anythign else = error */
            cddb_errno_log_error(c, CDDB_ERR_SERVER_ERROR);
            return FALSE;
    }

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}

void cddb_http_parse_headers(cddb_conn_t *c)
{
    char *line;

    cddb_log_debug("cddb_http_parse_headers()");
    while (((line = cddb_read_line(c)) != NULL) &&
           (*line != CHR_EOS)) {
        /* no-op */
    }
}

static int cddb_add_proxy_auth(cddb_conn_t *c)
{
    /* send proxy authorization if credentials are set */
    if (c->http_proxy_auth) {
        sock_fprintf(c, "Proxy-Authorization: Basic %s\r\n", c->http_proxy_auth);
    }
    return TRUE;
}

int cddb_http_send_cmd(cddb_conn_t *c, cddb_cmd_t cmd, va_list args)
{
    cddb_log_debug("cddb_http_send_cmd()");
    switch (cmd) {
        case CMD_WRITE:
            /* entry submission (POST method) */
            {
                char *category;
                int discid, size;
                
                category = va_arg(args, char *);
                discid = va_arg(args, int);
                size = va_arg(args, int);

                if (c->is_http_proxy_enabled) {
                    /* use an HTTP proxy */
                    sock_fprintf(c, "POST http://%s:%d%s HTTP/1.0\r\n", 
                                 c->server_name, c->server_port, c->http_path_submit);
                    sock_fprintf(c, "Host: %s:%d\r\n",
                                 c->server_name, c->server_port);
                    cddb_add_proxy_auth(c);
                } else {
                    /* direct connection */
                    sock_fprintf(c, "POST %s HTTP/1.0\r\n", c->http_path_submit);
                }

                sock_fprintf(c, "Category: %s\r\n", category);
                sock_fprintf(c, "Discid: %08x\r\n", discid);
                sock_fprintf(c, "User-Email: %s@%s\r\n", c->user, c->hostname);
                sock_fprintf(c, "Submit-Mode: submit\r\n");
                sock_fprintf(c, "Content-Length: %d\r\n", size);
                sock_fprintf(c, "Charset: UTF-8\r\n");
                sock_fprintf(c, "\r\n");
            }
            break;
        default:
            /* anything else */
            {
                char *buf;
                int rv;
                
                if (c->is_http_proxy_enabled) {
                    /* use an HTTP proxy */
                    sock_fprintf(c, "GET http://%s:%d%s?", 
                                 c->server_name, c->server_port, c->http_path_query);
                } else {
                    /* direct connection */
                    sock_fprintf(c, "GET %s?", c->http_path_query);
                }

                buf = (char*)malloc(c->buf_size);
                rv = vsnprintf(buf, c->buf_size, CDDB_COMMANDS[cmd], args);
                if (rv < 0 || rv >= c->buf_size) {
                    /* buffer is too small */
                    cddb_errno_log_crit(c, CDDB_ERR_LINE_SIZE);
                    return FALSE;
                }
                url_encode(buf);
                if (cmd == CMD_SEARCH) {
                    sock_fprintf(c, "%s", buf);
                } else {
                    sock_fprintf(c, "cmd=%s&", buf);
                    sock_fprintf(c, "hello=%s+%s+%s+%s&", 
                                 c->user, c->hostname, c->cname, c->cversion);
                    sock_fprintf(c, "proto=%d", DEFAULT_PROTOCOL_VERSION);
                }
                free(buf);
                sock_fprintf(c, " HTTP/1.0\r\n");

                if (c->is_http_proxy_enabled) {
                    /* insert host header */
                    sock_fprintf(c, "Host: %s:%d\r\n",
                                 c->server_name, c->server_port);
                    cddb_add_proxy_auth(c);
                }
                sock_fprintf(c, "\r\n");

                /* parse HTTP response line */
                if (!cddb_http_parse_response(c)) {
                    return FALSE;
                }

                /* skip HTTP response headers */
                cddb_http_parse_headers(c);
            }
    }

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}

int cddb_send_cmd(cddb_conn_t *c, int cmd, ...)
{
    va_list args;
    
    cddb_log_debug("cddb_send_cmd()");
    if (!CONNECTION_OK(c)) {
        cddb_errno_log_error(c, CDDB_ERR_NOT_CONNECTED);
        return FALSE;
    }
    
    va_start(args, cmd);
    if (c->is_http_enabled) {
        /* HTTP */
        if (!cddb_http_send_cmd(c, cmd, args)) {
            int errnum;

            errnum = cddb_errno(c); /* save error number */
            cddb_disconnect(c);
            cddb_errno_set(c, errnum); /* restore error number */
            return FALSE;
        }
    } else {
        /* CDDBP */
        sock_vfprintf(c, CDDB_COMMANDS[cmd], args);
        sock_fprintf(c, "\n");
    }
    va_end(args);

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}

#define STATE_START         0
#define STATE_TRACK_OFFSETS 1
#define STATE_DISC_LENGTH   2
#define STATE_DISC_TITLE    3
#define STATE_DISC_YEAR     4
#define STATE_DISC_GENRE    5
#define STATE_DISC_EXT      6
#define STATE_TRACK_TITLE   7
#define STATE_TRACK_EXT     8
#define STATE_PLAY_ORDER    9
#define STATE_END_DOT       10
#define STATE_STOP          11

#define MULTI_NONE          0
#define MULTI_ARTIST        1
#define MULTI_TITLE         2
#define MULTI_EXT           3

int cddb_parse_record(cddb_conn_t *c, cddb_disc_t *disc)
{
    char *line, *buf;
    int state, multi_line = MULTI_NONE;
#ifdef HAVE_REGEX_H
    regmatch_t matches[6];
#endif
    cddb_track_t *track;
    int cache_content;
    int track_no = 0, old_no = -1;

    cddb_log_debug("cddb_parse_record()");
    /* 
     * Do we need to cache the processed content ?  We cache if:
     *   1. caching is allowed (CACHE_ON or CACHE_ONLY) 
     * and
     *   2. a cached version does not yet exist
     */
    cache_content = !c->cache_read && (c->use_cache != CACHE_OFF) && 
                    !cddb_cache_exists(c, disc);
    if (cache_content) {
        /* create cache directory structure */
        /* XXX: what to do if mkdir fails? */
        cache_content = cddb_cache_mkdir(c, disc);
        cache_content &= cddb_cache_open(c, disc, "w");
    }
    cddb_log_debug("...cache_content: %s", (cache_content ? "yes" : "no"));

    state = STATE_START;
    while ((line = cddb_read_line(c)) != NULL) {

        if (cache_content) {
            fprintf(cddb_cache_file(c), "%s\n", line);
        }

        switch (state) {
            case STATE_START:
                cddb_log_debug("...state: START");
                if (regexec(REGEX_TRACK_FRAME_OFFSETS, line, 0, NULL, 0) == 0) {
                    /* expect a list of track frame offsets now */
                    state = STATE_TRACK_OFFSETS;
                }
                break;
            case STATE_TRACK_OFFSETS:
                cddb_log_debug("...state: TRACK OFFSETS");
                if (regexec(REGEX_TRACK_FRAME_OFFSET, line, 2, matches, 0) == 0) {
                    track = cddb_disc_get_track(disc, track_no);
                    if (!track) {
                        /* no such track present in disc structure yet */
                        track = cddb_track_new();
                        /* XXX: insert at track_no pos?? */
                        cddb_disc_add_track(disc, track);
                    }
                    track->frame_offset = cddb_regex_get_int(line, matches, 1);
                    track_no++;
                    break;
                } else {
                    /* expect disc length now */
                    state = STATE_DISC_LENGTH;
                }
            case STATE_DISC_LENGTH:
                cddb_log_debug("...state: DISC LENGTH");
                if (regexec(REGEX_DISC_LENGTH, line, 2, matches, 0) == 0) {
                    disc->length = cddb_regex_get_int(line, matches, 1);
                    /* expect disc title now */
                    state = STATE_DISC_TITLE;
                }            
                break;
            case STATE_DISC_TITLE:
                cddb_log_debug("...state: DISC TITLE");
                if (regexec(REGEX_DISC_TITLE, line, 5, matches, 0) == 0) {
                    /* XXX: more error detection possible! */
                    if (multi_line == MULTI_NONE) {
                        /* start parsing title or artist, delete current
                           track and artist in case this disc structure is
                           being reused from a previous read */
                        cddb_disc_set_artist(disc, NULL);
                        cddb_disc_set_title(disc, NULL);
                    }
                    if (matches[2].rm_so != -1) {
                        /* both artist and title of disc are specified */
                        buf = cddb_regex_get_string(line, matches, 2);
                        cddb_disc_append_artist(disc, buf);
                        free(buf);
                        buf = cddb_regex_get_string(line, matches, 3);
                        cddb_disc_append_title(disc, buf);
                        free(buf);
                        /* we should only get title continuations now */
                        multi_line = MULTI_TITLE;
                    } else {
                        /* only title or artist of disc on this line */
                        if (multi_line != MULTI_TITLE) {
                            /* this line is part of the artist name */
                            buf = cddb_regex_get_string(line, matches, 4);
                            cddb_disc_append_artist(disc, buf);
                            free(buf);
                            /* next line might be continuation of artist name */
                            multi_line = MULTI_ARTIST;
                        } else {
                            /* this line is part of the title */
                            buf = cddb_regex_get_string(line, matches, 4);
                            cddb_disc_append_title(disc, buf);
                            free(buf);
                        }
                    }
                    break;
                }
                if (multi_line == MULTI_NONE) {
                    /* not yet parsing multi-line DTITLE */
                    /* might be comment line, just skip it */
                    break;
                }
                /* if format was not 'artist / title' we assume that
                   the title and artist name are equal (see specs) */
                if (disc->artist != NULL && disc->title == NULL) {
                    cddb_disc_set_title(disc, disc->artist);
                }
                multi_line = MULTI_NONE;
                /* fall through to end multi-line disc title */
            case STATE_DISC_YEAR:
                cddb_log_debug("...state: DISC YEAR");
                if (regexec(REGEX_DISC_YEAR, line, 2, matches, 0) == 0) {
                    disc->year = cddb_regex_get_int(line, matches, 1);
                    /* expect disc genre now */
                    state = STATE_DISC_GENRE;
                    break;
                }
                /* fall through because disc year is optional */
            case STATE_DISC_GENRE:
                cddb_log_debug("...state: DISC GENRE");
                if (regexec(REGEX_DISC_GENRE, line, 2, matches, 0) == 0) {
                    buf = cddb_regex_get_string(line, matches, 1);
                    cddb_disc_set_genre(disc, buf);
                    free(buf);
                    /* expect track title now */
                    state = STATE_TRACK_TITLE;
                    break;
                }
                /* fall through because disc genre is optional */
            case STATE_TRACK_TITLE:
                cddb_log_debug("...state: TRACK TITLE");
                if (regexec(REGEX_TRACK_TITLE, line, 6, matches, 0) == 0) {
                    state = STATE_TRACK_TITLE;
                    track_no = cddb_regex_get_int(line, matches, 1);
                    track = cddb_disc_get_track(disc, track_no);
                    if (track == NULL) {
                        cddb_errno_log_error(c, CDDB_ERR_TRACK_NOT_FOUND);
                        return FALSE;
                    }
                    if (track_no != old_no) {
                        old_no = track_no;
                        /* reset multi-line flag, expect artist first */
                        multi_line = MULTI_ARTIST;
                        /* delete current title and artist in case this
                           track structure is being reused from a previous
                           read */
                        cddb_track_set_artist(track, NULL);
                        cddb_track_set_title(track, NULL);
                    }
                    if (matches[3].rm_so == -1) {
                        /* only title or artist of track on this line */
                        if (multi_line != MULTI_TITLE) {
                            /* this line might be part of the artist,
                               but if we don't encounter a ' / ' it's the title,
                               so we use the title space for now and fix it later
                               if needed (see below) */
                            buf = cddb_regex_get_string(line, matches, 5);
                            cddb_track_append_title(track, buf);
                            free(buf);
                        } else {
                            /* this line is part of the title */
                            buf = cddb_regex_get_string(line, matches, 5);
                            cddb_track_append_title(track, buf);
                            free(buf);
                        }
                    } else {
                        /* we might have put the artist in the title space,
                           fix this now (see artist) */
                        track->artist = track->title;
                        track->title = NULL;
                        /* both artist and title of track are specified */
                        buf = cddb_regex_get_string(line, matches, 3);
                        cddb_track_append_artist(track, buf);
                        free(buf);
                        buf = cddb_regex_get_string(line, matches, 4);
                        cddb_track_append_title(track, buf);
                        free(buf);
                        /* we should only get title continuations now */
                        multi_line = MULTI_TITLE;
                    }
                    /* valid track title, process next line */
                    break;
                }
                multi_line = MULTI_NONE;
                old_no = -1;
                /* fall through, we might have reached end of track titles */
            case STATE_DISC_EXT:
                cddb_log_debug("...state: DISC EXT");
                if (regexec(REGEX_DISC_EXT, line, 2, matches, 0) == 0) {
                    state = STATE_DISC_EXT;
                    if (multi_line == MULTI_NONE) {
                        /* start parsing extended disc data, delete
                           current data in case this disc structure is
                           being reused from a previous read */
                        cddb_disc_set_ext_data(disc, NULL);
                        multi_line = MULTI_EXT;
                    }
                    buf = cddb_regex_get_string(line, matches, 1);
                    cddb_disc_append_ext_data(disc, buf);
                    free(buf);
                    break;
                }
                multi_line = MULTI_NONE;
                /* fall through, reached end of multi-line extended disc data */
            case STATE_TRACK_EXT:
                cddb_log_debug("...state: TRACK EXT");
                if (regexec(REGEX_TRACK_EXT, line, 3, matches, 0) == 0) {
                    state = STATE_TRACK_EXT;
                    track_no = cddb_regex_get_int(line, matches, 1);
                    track = cddb_disc_get_track(disc, track_no);
                    if (track == NULL) {
                        cddb_errno_log_error(c, CDDB_ERR_TRACK_NOT_FOUND);
                        return FALSE;
                    }
                    if (track_no != old_no) {
                        old_no = track_no;
                        /* start parsing extended track data for a new
                           track, delete current data in case this
                           track structure is being reused from a
                           previous read */
                        cddb_track_set_ext_data(track, NULL);
                    }
                    buf = cddb_regex_get_string(line, matches, 2);
                    cddb_track_append_ext_data(track, buf);
                    free(buf);
                    break;
                }
                /* fall through, reached end of extended track data? */
            case STATE_PLAY_ORDER:
                cddb_log_debug("...state: PLAY ORDER");
                if (regexec(REGEX_PLAY_ORDER, line, 2, matches, 0) == 0) {
                    /* expect nothing more */
                    state = STATE_END_DOT;
                    break;
                }
                /* fall through, reached end? */
            case STATE_END_DOT:
                cddb_log_debug("...state: STOP");
                if (*line == CHR_DOT) {
                    /* server response ends with a dot, so end of parsing */
                    state = STATE_STOP;
                    break;
                }
            default:
                /* unexpected line */
                cddb_log_error("unexpected line = '%s'", line);
        }
        /* break if we have to stop parsing */
        if (state == STATE_STOP) {
            break;
        }
    }

    /* change state to STOP if end of stream reached */
    if (line == NULL) {
        state = STATE_STOP;
    }

    if (cache_content) {
        cddb_cache_close(c);
    }

    if (state != STATE_STOP) {
        /* something wrong with the CDDB entry (either the network
           response or the cached version) */
        if (c->cache_read) {
            /* we're reading from the cache, remove the invalid entry */
            char *fn = cddb_cache_file_name(c, disc);
            if (fn) {
                cddb_log_warn("removing invalid cache entry '%s'", fn);
                unlink(fn);
            }
            FREE_NOT_NULL(fn);
        }
        cddb_errno_log_error(c, CDDB_ERR_INVALID_RESPONSE);
        return FALSE;
    }

    if (!cddb_disc_iconv(c->charset->cd_from_freedb, disc)) {
        cddb_errno_log_error(c, CDDB_ERR_ICONV_FAIL);
        return FALSE;
    }

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}


/* --- server commands --- */


int cddb_read(cddb_conn_t *c, cddb_disc_t *disc)
{
    char *msg;
    int code, rc;

    cddb_log_debug("cddb_read()");
    /* check whether we have enough info to execute the command */
    if ((disc->category == CDDB_CAT_INVALID) || (disc->discid == 0)) {
        cddb_errno_log_error(c, CDDB_ERR_DATA_MISSING);
        return FALSE;
    }

    if (cddb_cache_read(c, disc)) {
        /* cached version found */
        return TRUE;
    } else if (c->use_cache == CACHE_ONLY) {
        /* no network access allowed */
        cddb_errno_set(c, CDDB_ERR_DISC_NOT_FOUND);
        return FALSE;
    }

    if (!cddb_connect(c)) {
        /* connection not OK */
        return FALSE;
    }

    /* send read command and check response */
    if (!cddb_send_cmd(c, CMD_READ, CDDB_CATEGORY[disc->category], disc->discid)) {
        return FALSE;
    }
    switch (code = cddb_get_response_code(c, &msg)) {
        case  -1:
            return FALSE;
        case 210:                   /* OK, CDDB database entry follows */
            break;
        case 401:                   /* specified CDDB entry not found */
            cddb_errno_set(c, CDDB_ERR_DISC_NOT_FOUND);
            return FALSE;
        case 402:                   /* server error */
        case 403:                   /* database entry is corrupt */
            cddb_errno_log_error(c, CDDB_ERR_SERVER_ERROR);
            return FALSE;
        case 409:                   /* no handshake */
        case 530:                   /* server error, server timeout */
            cddb_disconnect(c);
            cddb_errno_log_error(c, CDDB_ERR_NOT_CONNECTED);
            return FALSE;
        default:
            cddb_errno_log_error(c, CDDB_ERR_UNKNOWN);
            return FALSE;
    }

    /* parse CDDB record */
    rc = cddb_parse_record(c, disc);

    /* close connection if using HTTP */
    if (c->is_http_enabled) {
        cddb_disconnect(c);
    }

    return rc;
}

int cddb_parse_query_data(cddb_conn_t *c, cddb_disc_t *disc, const char *line)
{
    char *aux;
    regmatch_t matches[7];

    if (regexec(REGEX_QUERY_MATCH, line, 7, matches, 0) == REG_NOMATCH) {
        /* invalid repsponse */
        cddb_errno_log_error(c, CDDB_ERR_INVALID_RESPONSE);
        return FALSE;
    }
    /* extract category */
    aux = cddb_regex_get_string(line, matches, 1);
    cddb_disc_set_category_str(disc, aux);
    free(aux);                  /* free temporary buffer */
    /* extract disc ID */
    aux = cddb_regex_get_string(line, matches, 2);
    disc->discid = strtoll(aux, NULL, 16);
    free(aux);                  /* free temporary buffer */
    /* extract artist and title */
    if (matches[4].rm_so != -1) {
        /* both artist and title of disc are specified */
        disc->artist = cddb_regex_get_string(line, matches, 4);
        disc->title = cddb_regex_get_string(line, matches, 5);
    } else {
        /* only title of disc is specified */
        disc->title = cddb_regex_get_string(line, matches, 6);
    }        

    if (!cddb_disc_iconv(c->charset->cd_from_freedb, disc)) {
        cddb_errno_log_error(c, CDDB_ERR_ICONV_FAIL);
        return FALSE;
    }

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}

int cddb_query(cddb_conn_t *c, cddb_disc_t *disc)
{
    char *msg, *line;
    int code, count;
    char *buf, offset[32];
    cddb_track_t *track;

    cddb_log_debug("cddb_query()");
    /* clear previous query result set */
    list_flush(c->query_data);
    
    /* recalculate disc ID to make sure it matches the disc data */
    cddb_disc_calc_discid(disc);

    /* check whether we have enough info to execute the command */
    cddb_log_debug("...disc->discid    = %08x", disc->discid);
    cddb_log_debug("...disc->length    = %d", disc->length);
    cddb_log_debug("...disc->track_cnt = %d", disc->track_cnt);
    if ((disc->discid == 0) || (disc->length == 0) || (disc->track_cnt == 0)) {
        cddb_errno_log_error(c, CDDB_ERR_DATA_MISSING);
        return -1;
    }

    if (cddb_cache_query(c, disc)) {
        /* cached version found */
        return TRUE;
    } else if (c->use_cache == CACHE_ONLY) {
        /* no network access allowed */
        cddb_errno_set(c, CDDB_ERR_DISC_NOT_FOUND);
        return FALSE;
    }

    buf = (char*)malloc(c->buf_size);
    /* check track offsets and generate offset list */
    buf[0] = CHR_EOS;
    for (track = cddb_disc_get_track_first(disc); 
         track != NULL; 
         track = cddb_disc_get_track_next(disc)) {
        if (track->frame_offset == -1) {
            cddb_errno_log_error(c, CDDB_ERR_DATA_MISSING);
            free(buf);
            return -1;
        }
        snprintf(offset, sizeof(offset), "%d ", track->frame_offset);
        if (strlen(buf) + strlen(offset) >= c->buf_size) {
            /* buffer is too small */
            cddb_errno_log_crit(c, CDDB_ERR_LINE_SIZE);
            free(buf);
            return -1;
        }
        strcat(buf, offset);
    }

    if (!cddb_connect(c)) {
        /* connection not OK */
        free(buf);
        return -1;
    }

    /* send query command and check response */
    if (!cddb_send_cmd(c, CMD_QUERY, disc->discid, disc->track_cnt, buf, disc->length)) {
        free(buf);
        return -1;
    }
    free(buf);
    switch (code = cddb_get_response_code(c, &msg)) {
        case  -1:
            return -1;
        case 200:                   /* found exact match */
            cddb_log_debug("...exact match");
            if (!cddb_parse_query_data(c, disc, msg)) {
                return -1;
            }
            count = 1;
            break;
        case 210:                   /* found exact matches, list follows */
        case 211:                   /* found inexact matches, list follows */
            cddb_log_debug("...(in)exact matches");
            {
                cddb_disc_t *aux;

                while ((line = cddb_read_line(c)) != NULL) {
                    /* end of list? */
                    if (*line == CHR_DOT) {
                        break;
                    }
                    /* clone disc and fill in the blanks */
                    aux = cddb_disc_clone(disc);
                    if (!cddb_parse_query_data(c, aux, line)) {
                        cddb_disc_destroy(aux);
                        return -1;
                    }
                    list_append(c->query_data, aux);
                }
                if (list_size(c->query_data) == 0) {
                    /* empty result set */
                    cddb_errno_log_error(c, CDDB_ERR_INVALID_RESPONSE);
                    return -1;
                }
                /* return first disc in result set */
                cddb_disc_copy(disc, (cddb_disc_t *)element_data(list_first(c->query_data)));
            }
            count = list_size(c->query_data);
            break;
        case 202:                   /* no match found */
            cddb_log_debug("...no match");
            count = 0;
            break;
        case 403:                   /* database entry is corrupt */
            cddb_errno_log_error(c, CDDB_ERR_SERVER_ERROR);
            return -1;
        case 409:                   /* no handshake */
        case 530:                   /* server error, server timeout */
            cddb_disconnect(c);
            cddb_errno_log_error(c, CDDB_ERR_NOT_CONNECTED);
            return -1;
        default:
            cddb_errno_log_error(c, CDDB_ERR_UNKNOWN);
            return -1;
    }

    /* close connection if using HTTP */
    if (c->is_http_enabled) {
        cddb_disconnect(c);
    }

    cddb_log_debug("...number of matches: %d", count);
    cddb_errno_set(c, CDDB_ERR_OK);
    return count;
}

int cddb_query_next(cddb_conn_t *c, cddb_disc_t *disc)
{
    elem_t *aux;

    cddb_log_debug("cddb_query_next()");
    aux = list_next(c->query_data);
    if (!aux) {
        /* no more discs */
        cddb_errno_set(c, CDDB_ERR_DISC_NOT_FOUND);
        return FALSE;
    }
    /* return next disc in result set */
    cddb_disc_copy(disc, (cddb_disc_t *)element_data(aux));

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}

static int cddb_parse_search_data(cddb_conn_t *c, cddb_disc_t **disc,
                                  char *line, regmatch_t *matches)
{
    regmatch_t pre_matches[11];
    char *buf;

    /* HACK: because of greedy matching of POSIX regular expressions
       we first need to check whether the prefix remainder also
       contains a valid match. */
    buf = cddb_regex_get_string(line, matches, 1);
    if (regexec(REGEX_TEXT_SEARCH, buf, 11, pre_matches, 0) == 0) {
        cddb_parse_search_data(c, disc, buf, pre_matches);
    }
    free(buf);
    /* clone so that duplicate matches get correct artist and title */
    if (*disc) {
        *disc = cddb_disc_clone(*disc);
    } else {
        *disc = cddb_disc_new();
    }
    if (*disc == NULL) {
        cddb_errno_log_error(c, CDDB_ERR_OUT_OF_MEMORY);
        return FALSE;
    }
    /* fill in the results in the new disc */
    buf = cddb_regex_get_string(line, matches, 2);
    cddb_disc_set_category_str(*disc, buf);
    free(buf);
    cddb_disc_set_discid(*disc, cddb_regex_get_hex(line, matches, 3));
    if (matches[6].rm_so != -1) {
        buf = cddb_regex_get_string(line, matches, 6);
        cddb_disc_set_artist(*disc, buf);
        free(buf);
        buf = cddb_regex_get_string(line, matches, 7);
        cddb_disc_set_title(*disc, buf);
        free(buf);
    } else if (matches[8].rm_so != -1) {
        buf = cddb_regex_get_string(line, matches, 8);
        cddb_disc_set_artist(*disc, buf);
        cddb_disc_set_title(*disc, buf);
        free(buf);
    } else if (matches[10].rm_so != -1) {
        /* nothing to do, values should be correct because of cloning */
    }
    list_append(c->query_data, *disc);
    return TRUE;
}

/**
 * Build the search parameter string.
 */
static void cddb_search_param_str(cddb_search_params_t *params,
                                  char *buf, int len)
{
    char *p = buf;
    int i;

    /* XXX: to buffer overflow checking */
    strcpy(p, "&allfields="); p += 11;
    if (params->fields == SEARCH_ALL) {
        strcpy(p, "YES"); p += 3;
    } else {
        strcpy(p, "NO"); p += 2;
        if (params->fields & SEARCH_ARTIST) {
            strcpy(p, "&fields=artist"); p += 14;
        }
        if (params->fields & SEARCH_TITLE) {
            strcpy(p, "&fields=title"); p += 13;
        }
        if (params->fields & SEARCH_TRACK) {
            strcpy(p, "&fields=track"); p += 13;
        }
        if (params->fields & SEARCH_OTHER) {
            strcpy(p, "&fields=rest"); p += 12;
        }
    }
    strcpy(p, "&allcats="); p += 9;
    if (params->cats == SEARCH_ALL) {
        strcpy(p, "YES"); p += 3;
    } else {
        strcpy(p, "NO"); p += 2;
        for (i = 0; i < CDDB_CAT_INVALID; i++) {
            if (params->cats & SEARCHCAT(i)) {
                strcpy(p, "&cats="); p += 6;
                strcpy(p, CDDB_CATEGORY[i]); p += strlen(CDDB_CATEGORY[i]);
            }
        }
    }
    strcpy(p, "&grouping=cats"); p += 14;
}

int cddb_search(cddb_conn_t *c, cddb_disc_t *disc, const char *str)
{
    regmatch_t matches[11];
    char *line;
    int count;
    cddb_disc_t *aux = NULL;
    char paramstr[1024];        /* big enough! */

    /* NOTE: For server access this function uses the special
             'cddb_search_conn' connection structure. */
    cddb_log_debug("cddb_search()");
    /* copy proxy parameters */
    cddb_clone_proxy(cddb_search_conn, c);
    /* clear previous query result set */
    list_flush(c->query_data);
    
    if (!cddb_connect(cddb_search_conn)) {
        /* connection not OK, copy error code */
        cddb_errno_set(c, cddb_errno(cddb_search_conn));
        return -1;
    }

    /* prepare search parameters string */
    cddb_search_param_str(&c->srch, paramstr, sizeof(paramstr));
    
    /* send query command and check response */
    if (!cddb_send_cmd(cddb_search_conn, CMD_SEARCH, str, paramstr)) {
        /* sending command failed, copy error code */
        cddb_errno_set(c, cddb_errno(cddb_search_conn));
        return -1;
    }

    /* parse HTML response page */
    while ((line = cddb_read_line(cddb_search_conn)) != NULL) {
        if (regexec(REGEX_TEXT_SEARCH, line, 11, matches, 0) == 0) {
            /* process matching result line */
            if (!cddb_parse_search_data(c, &aux, line, matches)) {
                return -1;
            }
        }
    }
    /* return first disc in result set */
    count = list_size(c->query_data);
    if (count  != 0) {
        cddb_disc_copy(disc, 
                       (cddb_disc_t *)element_data(list_first(c->query_data)));
    }
    /* close connection */
    cddb_disconnect(cddb_search_conn);

    cddb_log_debug("...number of matches: %d", count);
    cddb_errno_set(c, CDDB_ERR_OK);
    return count;
}

int cddb_search_next(cddb_conn_t *c, cddb_disc_t *disc)
{
    cddb_log_debug("cddb_search_next() ->");
    return cddb_query_next(c, disc);
}

int cddb_write_data(cddb_conn_t *c, char *buf, int size, cddb_disc_t *disc)
{
    int i, remaining;
    cddb_track_t *track;
    const char *s;

/* Appends some data to the buffer.  The first parameter is the
   number of bytes that will be added.  The other parameters are a
   format string and its arguments as in printf. */
/* XXX: error checking on buffer size */
#define CDDB_WRITE_APPEND(l, ...) \
            snprintf(buf, remaining, __VA_ARGS__); remaining -= l; buf += l;

    remaining = size;
    CDDB_WRITE_APPEND(9, "# xmcd\n#\n");
    /* track offsets */
    CDDB_WRITE_APPEND(23, "# Track frame offsets:\n");
    for (track = cddb_disc_get_track_first(disc); 
         track != NULL; 
         track = cddb_disc_get_track_next(disc)) {
        CDDB_WRITE_APPEND(6+8, "#    %8d\n", track->frame_offset);
    }
    /* disc length */
    CDDB_WRITE_APPEND(26+6, "#\n# Disc length: %6d seconds\n", disc->length);
    /* submission info */
    CDDB_WRITE_APPEND(16, "#\n# Revision: 0\n");
    CDDB_WRITE_APPEND(21+strlen(c->cname)+strlen(c->cversion),
                      "# Submitted via: %s %s\n#\n", c->cname, c->cversion);
    /* disc data */
    CDDB_WRITE_APPEND(8+8, "DISCID=%08x\n", disc->discid);
    CDDB_WRITE_APPEND(11+strlen(disc->artist)+strlen(disc->title),
                      "DTITLE=%s / %s\n", disc->artist, disc->title);
    if (disc->year != 0) {
        CDDB_WRITE_APPEND(7+4, "DYEAR=%d\n", disc->year);
    } else {
        CDDB_WRITE_APPEND(7, "DYEAR=\n");
    }
    if (disc->genre && (*disc->genre != '\0')) {
        s = disc->genre;
    } else {
        s = CDDB_CATEGORY[disc->category];
    }
    CDDB_WRITE_APPEND(8+strlen(s), "DGENRE=%s\n", s);
    /* track data */
    for (track = cddb_disc_get_track_first(disc), i=0; 
         track != NULL; 
         track = cddb_disc_get_track_next(disc), i++) {
        if (track->artist != NULL) {
            CDDB_WRITE_APPEND(11+(i/10+1)+strlen(track->artist)+strlen(track->title),
                              "TTITLE%d=%s / %s\n", i, track->artist, track->title);
        } else {
            CDDB_WRITE_APPEND(8+(i/10+1)+strlen(track->title),
                              "TTITLE%d=%s\n", i, track->title);
        }
    }
    /* extended data */
    if (disc->ext_data != NULL) {
        CDDB_WRITE_APPEND(6+strlen(disc->ext_data), "EXTD=%s\n", disc->ext_data);
    } else {
        CDDB_WRITE_APPEND(6, "EXTD=\n");
    }
    for (track = cddb_disc_get_track_first(disc), i=0; 
         track != NULL; 
         track = cddb_disc_get_track_next(disc), i++) {
        if (track->ext_data != NULL) {
            CDDB_WRITE_APPEND(6+(i/10+1)+strlen(track->ext_data), 
                              "EXTT%d=%s\n", i, track->ext_data);
        } else {
            CDDB_WRITE_APPEND(6+(i/10+1), "EXTT%d=\n", i);
        }
    }
    /* play order */
    CDDB_WRITE_APPEND(11, "PLAYORDER=\n");

    return (size - remaining);
}

int cddb_write(cddb_conn_t *c, cddb_disc_t *disc)
{
    char *msg;
    int code, size;
    cddb_track_t *track;
    char buf[WRITE_BUF_SIZE];

    cddb_log_debug("cddb_write()");
    /* check whether the default e-mail address has been changed, the
       freedb spec requires this */
    if (strcmp(c->user, DEFAULT_USER) == 0 ||
        strcmp(c->hostname, DEFAULT_HOST) == 0) {
        cddb_errno_log_error(c, CDDB_ERR_EMAIL_INVALID);
        return FALSE;
    }
    /* check whether we have enough disc data to execute the command */
    if ((disc->discid == 0) || (disc->category == CDDB_CAT_INVALID) || 
        (disc->length == 0) || (disc->track_cnt == 0) ||
        (disc->artist == NULL) || (disc->title == NULL)) {
        cddb_errno_log_error(c, CDDB_ERR_DATA_MISSING);
        return FALSE;
    }

    /* check whether we have enough track data to execute the command */
    for (track = cddb_disc_get_track_first(disc); 
         track != NULL; 
         track = cddb_disc_get_track_next(disc)) {
        if ((track->frame_offset == -1) || (track->title == NULL)) {
            cddb_errno_log_error(c, CDDB_ERR_DATA_MISSING);
            return FALSE;
        }
    }

    /* convert to FreeDB character set */
    if (!cddb_disc_iconv(c->charset->cd_to_freedb, disc)) {
        cddb_errno_log_error(c, CDDB_ERR_ICONV_FAIL);
        return FALSE;
    }

    /* create CDDB entry */
    size = cddb_write_data(c, buf, sizeof(buf), disc);
    
    /* cache data if needed */
    if (c->use_cache != CACHE_OFF) {
        /* create cache directory structure */
        /* XXX: what to do if mkdir fails? */
        if (cddb_cache_mkdir(c, disc)) {
            /* open file, possibly overwriting it */
            cddb_log_debug("...caching data");
            cddb_cache_open(c, disc, "w");
            fwrite(buf, sizeof(char), size, cddb_cache_file(c));
            cddb_cache_close(c);
        }
    }

    /* stop if no network access is allowed */
    if (c->use_cache == CACHE_ONLY) {
        cddb_errno_set(c, CDDB_ERR_OK);
        return TRUE;
    }
    
    if (!cddb_connect(c)) {
        /* connection not OK */
        return FALSE;
    }

    /* send query command and check response */
    if (!cddb_send_cmd(c, CMD_WRITE, CDDB_CATEGORY[disc->category], disc->discid, size)) {
        return FALSE;
    }
    if (!c->is_http_enabled) {
        switch (code = cddb_get_response_code(c, &msg)) {
            case  -1:
                return FALSE;
            case 320:                   /* OK, input CDDB data */
                break;
            case 401:                   /* permission denied */
            case 402:                   /* server file system full/file access failed */
            case 501:                   /* entry rejected */
                cddb_errno_log_error(c, CDDB_ERR_PERMISSION_DENIED);
                return FALSE;
            case 409:                   /* no handshake */
            case 530:                   /* server error, server timeout */
                cddb_disconnect(c);
                cddb_errno_log_error(c, CDDB_ERR_NOT_CONNECTED);
                return FALSE;
            default:
                cddb_errno_log_error(c, CDDB_ERR_UNKNOWN);
                return FALSE;
        }
    }

    /* ready to send data */
    cddb_log_debug("...sending data");
    sock_fwrite(buf, sizeof(char), size, c);
    if (c->is_http_enabled) {
        /* skip HTTP response headers */
        cddb_http_parse_headers(c);
    } else {
        /* send terminating marker */
        sock_fprintf(c, ".\n");
    }

    /* check response */
    switch (code = cddb_get_response_code(c, &msg)) {
        case  -1:
            return FALSE;
        case 200:                   /* CDDB entry accepted */
            cddb_log_debug("...entry accepted");
            break;
        case 401:                   /* CDDB entry rejected */
        case 500:                   /* (HTTP) Missing required header information */
        case 501:                   /* (HTTP) Invalid header information */
            cddb_log_debug("...entry not accepted");
            cddb_errno_log_error(c, CDDB_ERR_REJECTED);
            return FALSE;
        case 530:                   /* server error, server timeout */
            cddb_disconnect(c);
            cddb_errno_log_error(c, CDDB_ERR_NOT_CONNECTED);
            return FALSE;
        default:
            cddb_errno_log_error(c, CDDB_ERR_UNKNOWN);
            return FALSE;
    }

    /* close connection if using HTTP */
    if (c->is_http_enabled) {
        cddb_disconnect(c);
    }

    cddb_errno_set(c, CDDB_ERR_OK);
    return TRUE;
}

int cddb_sites(cddb_conn_t *c)
{
    char *msg, *line;
    int code;
    cddb_site_t *site;

    cddb_log_debug("cddb_sites()");
    /* clear previous sites result set */
    list_flush(c->sites_data);

    if (!cddb_connect(c)) {
        /* connection not OK */
        return FALSE;
    }

    /* send sites command and check response */
    if (!cddb_send_cmd(c, CMD_SITES)) {
        return FALSE;
    }
    switch (code = cddb_get_response_code(c, &msg)) {
        case  -1:
            return FALSE;
        case 210:                   /* OK, site information follows */
            break;
        case 401:                   /* no site information */
            return FALSE;
        default:
            cddb_errno_log_error(c, CDDB_ERR_UNKNOWN);
            return FALSE;
    }

    while ((line = cddb_read_line(c)) != NULL) {
        /* end of list? */
        if (*line == CHR_DOT) {
            break;
        }
        site = cddb_site_new();
        if (!site) {
            cddb_errno_log_error(c, CDDB_ERR_OUT_OF_MEMORY);
            return FALSE;
        }
        if (!cddb_site_parse(site, line)) {
            /* skip parsing errors */
            cddb_log_warn("unable to parse site: %s", line);
            cddb_site_destroy(site);
            continue;
        }
        if (!cddb_site_iconv(c->charset->cd_from_freedb, site)) {
            cddb_errno_log_error(c, CDDB_ERR_ICONV_FAIL);
            cddb_site_destroy(site);
            return FALSE;
        }
        if (!list_append(c->sites_data, site)) {
            cddb_errno_log_error(c, CDDB_ERR_OUT_OF_MEMORY);
            cddb_site_destroy(site);
            return FALSE;
        }
    }

    /* close connection if using HTTP */
    if (c->is_http_enabled) {
        cddb_disconnect(c);
    }

    return TRUE;
}
