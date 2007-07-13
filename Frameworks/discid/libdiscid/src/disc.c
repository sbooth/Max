/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2006 Matthias Friedrich
   Copyright (C) 2000 Robert Kaye
   Copyright (C) 1999 Marc E E van Woerkom
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

     $Id: disc.c 8505 2006-09-30 00:02:18Z luks $

--------------------------------------------------------------------------- */
#include <string.h>
#include <assert.h>

#include "sha1.h"
#include "base64.h"

#include "discid/discid.h"
#include "discid/discid_private.h"


#define TRACK_NUM_IS_VALID(disc, i) \
	( i >= disc->first_track_num && i <= disc->last_track_num )


static void create_disc_id(mb_disc_private *d, char buf[]);
static void create_freedb_disc_id(mb_disc_private *d, char buf[]);
static void create_submission_url(mb_disc_private *d, char buf[]);



/****************************************************************************
 *
 * Implementation of the public interface.
 *
 ****************************************************************************/

DiscId *discid_new() {
	/* initializes everything to zero */
	return calloc(1, sizeof(mb_disc_private));
}


void discid_free(DiscId *d) {
	free(d);
}


char *discid_get_error_msg(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;
	assert( disc != NULL );

	return disc->error_msg;
}


char *discid_get_id(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;
	assert( disc != NULL );
	assert( disc->success );

	if ( ! disc->success )
		return NULL;

	if ( strlen(disc->id) == 0 )
		create_disc_id(disc, disc->id);

	return disc->id;
}


char *discid_get_freedb_id(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;
	assert( disc != NULL );
	assert( disc->success );

	if ( ! disc->success )
		return NULL;

	if ( strlen(disc->freedb_id) == 0 )
		create_freedb_disc_id(disc, disc->freedb_id);

	return disc->freedb_id;
}


char *discid_get_submission_url(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;
	assert( disc != NULL );
	assert( disc->success );

	if ( ! disc->success )
		return NULL;

	if ( strlen(disc->submission_url) == 0 )
		create_submission_url(disc, disc->submission_url);

	return disc->submission_url;
}


int discid_read(DiscId *d, const char *device) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );

	if ( device == NULL )
		device = discid_get_default_device();

	assert( device != NULL );

	/* Necessary, because the disc handle could have been used before. */
	memset(disc, 0, sizeof(mb_disc_private));

	return disc->success = mb_disc_read_unportable(disc, device);
}


int discid_put(DiscId *d, int first, int last, int *offsets) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );

	memset(disc, 0, sizeof(mb_disc_private));

	if ( first > last || first < 1 || first > 99 || last < 1
			|| last > 99 || offsets==NULL ) {

		sprintf(disc->error_msg, "Illegal parameters");
		return 0;
	}

	disc->first_track_num = first;
	disc->last_track_num = last;

	memcpy(disc->track_offsets, offsets, sizeof(int) * (last+1));

	disc->success = 1;

	return 1;
}


char *discid_get_default_device(void) {
	return mb_disc_get_default_device_unportable();
}


int discid_get_first_track_num(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );

	return disc->first_track_num;
}


int discid_get_last_track_num(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );

	return disc->last_track_num;
}


int discid_get_sectors(DiscId *d) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );

	return disc->track_offsets[0];
}


int discid_get_track_offset(DiscId *d, int i) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );
	assert( TRACK_NUM_IS_VALID(disc, i) );

	if ( ! TRACK_NUM_IS_VALID(disc, i) )
		return 0;

	return disc->track_offsets[i];
}


int discid_get_track_length(DiscId *d, int i) {
	mb_disc_private *disc = (mb_disc_private *) d;

	assert( disc != NULL );
	assert( TRACK_NUM_IS_VALID(disc, i) );

	if ( ! TRACK_NUM_IS_VALID(disc, i) )
		return 0;

	if ( i < disc->last_track_num )
		return disc->track_offsets[i+1] - disc->track_offsets[i];
	else
		return disc->track_offsets[0] - disc->track_offsets[i];
}


/****************************************************************************
 *
 * Private utilities, not exported.
 *
 ****************************************************************************/

/*
 * Create a DiscID based on the TOC data found in the DiscId object.
 * The DiscID is placed in the provided string buffer.
 */
static void create_disc_id(mb_disc_private *d, char buf[]) {
	SHA_INFO	sha;
	unsigned char	digest[20], *base64;
	unsigned long	size;
	char		tmp[17]; /* for 8 hex digits (16 to avoid trouble) */
	int		i;

	assert( d != NULL );

	sha_init(&sha);

	sprintf(tmp, "%02X", d->first_track_num);
	sha_update(&sha, (unsigned char *) tmp, strlen(tmp));

	sprintf(tmp, "%02X", d->last_track_num);
	sha_update(&sha, (unsigned char *) tmp, strlen(tmp));

	for (i = 0; i < 100; i++) {
		sprintf(tmp, "%08X", d->track_offsets[i]);
		sha_update(&sha, (unsigned char *) tmp, strlen(tmp));
	}

	sha_final(digest, &sha);

	base64 = rfc822_binary(digest, sizeof(digest), &size);

	memcpy(buf, base64, size);
	buf[size] = '\0';

	free(base64);
}


/*
 * Create a FreeDB DiscID based on the TOC data found in the DiscId object.
 * The DiscID is placed in the provided string buffer.
 */
static void create_freedb_disc_id(mb_disc_private *d, char buf[]) {
	int i, n, m, t;

	assert( d != NULL );

	n = 0;
	for (i = 0; i < d->last_track_num; i++) {
		m = d->track_offsets[i + 1] / 75;
		while (m > 0) {
			n += m % 10;
			m /= 10;
		}
	}
	t = d->track_offsets[0] / 75 - d->track_offsets[1] / 75;
	sprintf(buf, "%08x", ((n % 0xff) << 24 | t << 8 | d->last_track_num));
}


/*
 * Create a submission URL based on the TOC data found in the mb_disc_private
 * object. The URL is placed in the provided string buffer.
 */
static void create_submission_url(mb_disc_private *d, char buf[]) {
	char tmp[1024];
	int i;

	assert( d != NULL );

	strcpy(buf, MB_SUBMISSION_URL);

	strcat(buf, "?id=");
	strcat(buf, discid_get_id((DiscId *) d));

	sprintf(tmp, "&tracks=%d", d->last_track_num);
	strcat(buf, tmp);

	sprintf(tmp, "&toc=%d+%d+%d",
			d->first_track_num,
			d->last_track_num,
			d->track_offsets[0]);
	strcat(buf, tmp);

	for (i = d->first_track_num; i <= d->last_track_num; i++) {
		sprintf(tmp, "+%d", d->track_offsets[i]);
		strcat(buf, tmp);
	}
}

/* EOF */
