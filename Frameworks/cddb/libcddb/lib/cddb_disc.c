/*
    $Id: cddb_disc.c,v 1.23 2005/07/09 08:37:13 airborne Exp $

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

#include <math.h>
#include <stdlib.h>
#ifdef HAVE_STRING_H
#include <string.h>
#endif


const char *CDDB_CATEGORY[CDDB_CAT_LAST] = {
    "data", "folk", "jazz", "misc", "rock", "country", "blues", "newage",
    "reggae", "classical", "soundtrack",
    "invalid"
};


/* --- private functions */


int cddb_disc_iconv(iconv_t cd, cddb_disc_t *disc)
{ 
    char *result;
    cddb_track_t *track;

    if (!cd) {
        return TRUE;            /* no user character set defined */
    }
    if (disc->genre) {
        if (cddb_str_iconv(cd, disc->genre, &result)) {
            free(disc->genre);
            disc->genre = result;
        } else {
            return FALSE;
        }
    }
    if (disc->title) {
        if (cddb_str_iconv(cd, disc->title, &result)) {
            free(disc->title);
            disc->title = result;
        } else {
            return FALSE;
        }
    }
    if (disc->artist) {
        if (cddb_str_iconv(cd, disc->artist, &result)) {
            free(disc->artist);
            disc->artist = result;
        } else {
            return FALSE;
        }
    }
    if (disc->ext_data) {
        if (cddb_str_iconv(cd, disc->ext_data, &result)) {
            free(disc->ext_data);
            disc->ext_data = result;
        } else {
            return FALSE;
        }
    }
    track = disc->tracks;
    while (track) {
        if (!cddb_track_iconv(cd, track)) {
            return FALSE;
        }
        track = track->next;
    }
    return TRUE;
}


/* --- construction / destruction */


cddb_disc_t *cddb_disc_new(void)
{
    cddb_disc_t *disc;

    disc = (cddb_disc_t*)calloc(1, sizeof(cddb_disc_t));
    if (disc) {
        disc->category = CDDB_CAT_INVALID;
    } else {
        cddb_log_crit(cddb_error_str(CDDB_ERR_OUT_OF_MEMORY));
    }

    return disc;
}

void cddb_disc_destroy(cddb_disc_t *disc)
{
    cddb_track_t *track, *next;

    if (disc) {
        FREE_NOT_NULL(disc->genre);
        FREE_NOT_NULL(disc->title);
        FREE_NOT_NULL(disc->artist);
        FREE_NOT_NULL(disc->ext_data);
        track = disc->tracks;
        while (track) {
            next = track->next;
            cddb_track_destroy(track);
            track = next;
        }
        free(disc);
    }
}

cddb_disc_t *cddb_disc_clone(const cddb_disc_t *disc)
{
    cddb_disc_t *clone;
    cddb_track_t *track;

    cddb_log_debug("cddb_disc_clone()");
    clone = cddb_disc_new();
    clone->discid = disc->discid;
    clone->category = disc->category;
    clone->year = disc->year;
    clone->genre = (disc->genre ? strdup(disc->genre) : NULL);
    clone->title = (disc->title ? strdup(disc->title) : NULL);
    clone->artist = (disc->artist ? strdup(disc->artist) : NULL);
    clone->length = disc->length;
    clone->ext_data = (disc->ext_data ? strdup(disc->ext_data) : NULL);
    /* clone the tracks */
    track = disc->tracks;
    while (track) {
        cddb_disc_add_track(clone, cddb_track_clone(track));
        track = track->next;
    }
    return clone;
}


/* --- track manipulation */


void cddb_disc_add_track(cddb_disc_t *disc, cddb_track_t *track)
{
    cddb_log_debug("cddb_disc_add_track()");
    if (!disc->tracks) {
        /* first track on disc */
        disc->tracks = track;
    } else {
        /* next track on disc */
        cddb_track_t *t;

        t = disc->tracks;
        while (t->next) {
            t = t->next;
        }
        t->next = track;
        track->prev = t;
    }
    disc->track_cnt++;
    track->num = disc->track_cnt;
    track->disc = disc;
}

cddb_track_t *cddb_disc_get_track(const cddb_disc_t *disc, int track_no)
{
    cddb_track_t *track;
    
    if (track_no >= disc->track_cnt) {
        return NULL;
    }

    for (track = disc->tracks; 
         track_no > 0; 
         track_no--, track = track->next) { /* no-op */ }
    /* XXX: should we check track->num?? */
    return track;
}

cddb_track_t *cddb_disc_get_track_first(cddb_disc_t *disc)
{
    disc->iterator = disc->tracks;
    return disc->iterator;
}

cddb_track_t *cddb_disc_get_track_next(cddb_disc_t *disc)
{
    if (disc->iterator != NULL) {
        disc->iterator = disc->iterator->next;
    }
    return disc->iterator;
}


/* --- setters / getters --- */


unsigned int cddb_disc_get_discid(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->discid;
    } return 0;
}

void cddb_disc_set_discid(cddb_disc_t *disc, unsigned int id)
{
    if (disc) {
        disc->discid = id;
    }
}

cddb_cat_t cddb_disc_get_category(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->category;
    }
    return CDDB_CAT_INVALID;
}

void cddb_disc_set_category(cddb_disc_t *disc, cddb_cat_t cat)
{
    if (disc) {
        disc->category = cat;
    }
}

const char *cddb_disc_get_category_str(cddb_disc_t *disc)
{
    if (disc) {
        return CDDB_CATEGORY[disc->category];
    } else {
        return NULL;
    }
}

void cddb_disc_set_category_str(cddb_disc_t *disc, const char *cat)
{
    int i;

    FREE_NOT_NULL(disc->genre);
    disc->genre = strdup(cat);
    disc->category = CDDB_CAT_MISC;
    for (i = 0; i < CDDB_CAT_LAST; i++) {
        if (strcmp(cat, CDDB_CATEGORY[i]) == 0) {
            disc->category = i;
            return;
        }
    }
}

const char *cddb_disc_get_genre(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->genre;
    }
    return NULL;
}

void cddb_disc_set_genre(cddb_disc_t *disc, const char *genre)
{
    if (disc) {
        FREE_NOT_NULL(disc->genre);
        disc->genre = strdup(genre);
    }
}

unsigned int cddb_disc_get_length(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->length;
    }
    return 0;
}

void cddb_disc_set_length(cddb_disc_t *disc, unsigned int l)
{
    if (disc) {
        disc->length = l;
    }
}

unsigned int cddb_disc_get_year(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->year;
    }
    return 0;
}

void cddb_disc_set_year(cddb_disc_t *disc, unsigned int y)
{
    if (disc) {
        disc->year = y;
    }
}

int cddb_disc_get_track_count(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->track_cnt;
    }
    return -1;
}

const char *cddb_disc_get_title(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->title;
    }
    return NULL;
}

void cddb_disc_set_title(cddb_disc_t *disc, const char *title)
{
    if (disc) {
        FREE_NOT_NULL(disc->title);
        if (title) {
            disc->title = strdup(title);
        }
    }
}

void cddb_disc_append_title(cddb_disc_t *disc, const char *title)
{
    int old_len = 0, len;

    if (disc && title) {
        /* only append if there is something to append */
        if (disc->title) {
            old_len = strlen(disc->title);
        }
        len = strlen(title);
        disc->title = realloc(disc->title, old_len+len+1);
        strcpy(disc->title+old_len, title);
        disc->title[old_len+len] = '\0';
    }
}

const char *cddb_disc_get_artist(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->artist;
    }
    return NULL;
}

void cddb_disc_set_artist(cddb_disc_t *disc, const char *artist)
{
    if (disc) {
        FREE_NOT_NULL(disc->artist);
        if (artist) {
            disc->artist = strdup(artist);
        }
    }
}

void cddb_disc_append_artist(cddb_disc_t *disc, const char *artist)
{
    int old_len = 0, len;

    if (disc && artist) {
        /* only append if there is something to append */
        if (disc->artist) {
            old_len = strlen(disc->artist);
        }
        len = strlen(artist);
        disc->artist = realloc(disc->artist, old_len+len+1);
        strcpy(disc->artist+old_len, artist);
        disc->artist[old_len+len] = '\0';
    }
}

const char *cddb_disc_get_ext_data(const cddb_disc_t *disc)
{
    if (disc) {
        return disc->ext_data;
    }
    return NULL;
}

void cddb_disc_set_ext_data(cddb_disc_t *disc, const char *ext_data)
{
    if (disc) {
        FREE_NOT_NULL(disc->ext_data);
        if (ext_data) {
            disc->ext_data = strdup(ext_data);
        }
    }
}

void cddb_disc_append_ext_data(cddb_disc_t *disc, const char *ext_data)
{
    int old_len = 0, len;

    if (disc && ext_data) {
        /* only append if there is something to append */
        if (disc->ext_data) {
            old_len = strlen(disc->ext_data);
        }
        len = strlen(ext_data);
        disc->ext_data = realloc(disc->ext_data, old_len+len+1);
        strcpy(disc->ext_data+old_len, ext_data);
        disc->ext_data[old_len+len] = '\0';
    }
}


/* --- miscellaneous */


void cddb_disc_copy(cddb_disc_t *dst, cddb_disc_t *src)
{
    cddb_track_t *src_track, *dst_track;

    cddb_log_debug("cddb_disc_copy()");
    if (src->discid != 0) {
        dst->discid = src->discid;
    }
    if (src->category != CDDB_CAT_INVALID) {
        dst->category = src->category;
    }
    if (src->year != 0) {
        dst->year = src->year;
    }
    if (src->genre != NULL) {
        FREE_NOT_NULL(dst->genre);
        dst->genre = strdup(src->genre);
    }
    if (src->title != NULL) {
        FREE_NOT_NULL(dst->title);
        dst->title = strdup(src->title);
    }
    if (src->artist) {
        FREE_NOT_NULL(dst->artist);
        dst->artist = strdup(src->artist);
    }
    if (src->length != 0) {
        dst->length = src->length;
    }
    if (src->ext_data != NULL) {
        FREE_NOT_NULL(dst->ext_data);
        dst->ext_data = strdup(src->ext_data);
    }
    /* copy the tracks */
    src_track = src->tracks;
    dst_track = dst->tracks;
    while (src_track) {
        if (dst_track == NULL) {
            dst_track = cddb_track_new();
            cddb_disc_add_track(dst, dst_track);
        }
        cddb_track_copy(dst_track, src_track);
        src_track = src_track->next;
        dst_track = dst_track->next;
    }
}

int cddb_disc_calc_discid(cddb_disc_t *disc)
{
    long result = 0;
    long tmp;
    cddb_track_t *track, *first;

    cddb_log_debug("cddb_disc_calc_discid()");
    for (first = track = cddb_disc_get_track_first(disc); 
         track != NULL; 
         track = cddb_disc_get_track_next(disc)) {
        tmp = FRAMES_TO_SECONDS(track->frame_offset);
        do {
            result += tmp % 10;
            tmp /= 10;
        } while (tmp != 0);
    }

    if (first == NULL) {
        /* set disc id to zero if there are no tracks */
        disc->discid = 0;
    } else {
        /* first byte is offsets of tracks
         * 2 next bytes total length in seconds
         * last byte is nr of tracks
         */
        disc->discid = (result % 0xff) << 24 | 
                       (disc->length - FRAMES_TO_SECONDS(first->frame_offset)) << 8 | 
                       disc->track_cnt;
    }
    cddb_log_debug("...Disc ID: %08x", disc->discid);

    return TRUE;
}

void cddb_disc_print(cddb_disc_t *disc)
{
    cddb_track_t *track;
    int cnt;

    printf("Disc ID: %08x\n", disc->discid);
    printf("CDDB category: %s (%d)\n", CDDB_CATEGORY[disc->category], disc->category);
    printf("Music genre: '%s'\n", STR_OR_NULL(disc->genre));
    printf("Year: %d\n", disc->year);
    printf("Artist: '%s'\n", STR_OR_NULL(disc->artist));
    printf("Title: '%s'\n", STR_OR_NULL(disc->title));
    printf("Extended data: '%s'\n", STR_OR_NULL(disc->ext_data));
    printf("Length: %d seconds\n", disc->length);
    printf("Number of tracks: %d\n", disc->track_cnt);
    track = disc->tracks;
    cnt = 1;
    while (track) {
        printf("  Track %2d\n", cnt);
        cddb_track_print(track);
        track = track->next;
        cnt++;
    }
}
