/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2006 Matthias Friedrich
   
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

     $Id: discid_private.h 8505 2006-09-30 00:02:18Z luks $

--------------------------------------------------------------------------- */
/*
 * For internal use only. This header file is not installed.
 */
#ifndef MUSICBRAINZ_DISC_ID_PRIVATE_H
#define MUSICBRAINZ_DISC_ID_PRIVATE_H


/* Length of a MusicBrainz DiscID in bytes (without a trailing '\0'-byte). */
#define MB_DISC_ID_LENGTH		32

/* Length of a FreeDB DiscID in bytes (without a trailing '\0'-byte). */
#define FREEDB_DISC_ID_LENGTH	8

/* The maximum permitted length for an error message (without the '\0'-byte). */
#define MB_ERROR_MSG_LENGTH		255

/* URL prefix + 100 tracks, 5 bytes each + 32 bytes discid */
#define MB_MAX_URL_LENGTH		1023

/* The URL that can be used for submitting DiscIDs (no parameters yet) */
#define MB_SUBMISSION_URL		"http://mm.musicbrainz.org/bare/cdlookup.html"


/*
 * This data structure represents an audio disc.
 *
 * We use fixed length strings here because that way the user doesn't have to
 * check for memory exhaustion conditions. As soon as the mb_disc object has
 * been created, all calls returning strings will be successful.
 */
typedef struct {
	int first_track_num;
	int last_track_num;
	int track_offsets[100];
	char id[MB_DISC_ID_LENGTH+1];
	char freedb_id[FREEDB_DISC_ID_LENGTH+1];
	char submission_url[MB_MAX_URL_LENGTH+1];
	char error_msg[MB_ERROR_MSG_LENGTH+1];
	int success;
} mb_disc_private;


/*
 * This function has to be implemented once per operating system.
 *
 * The caller guarantees that both the disc and device parameters are
 * not NULL.
 *
 * Implementors have to set mb_disc_private's first_track_num, last_track_num,
 * and track_offsets attributes. If there is an error, the error_msg attribute
 * has to be set to a human-readable error message.
 *
 * On error, 0 is returned. On success, 1 is returned.
 */
int mb_disc_read_unportable(mb_disc_private *disc, const char *device);


/*
 * This should return the name of the default/preferred CDROM/DVD device 
 * on this operating system. It has to be in a format usable for the second
 * parameter of mb_disc_read_unportable().
 */
char *mb_disc_get_default_device_unportable(void);


#endif /* MUSICBRAINZ_DISC_ID_PRIVATE_H */
