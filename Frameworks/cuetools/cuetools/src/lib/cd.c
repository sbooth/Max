/*
 * cd.c -- cd functions
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cd.h"

typedef struct Data Data;
struct Data {
	int type;			/* DataType */
	char *name;			/* data source name */
	long start;			/* start time for data */
	long length;			/* length of data */
};

struct Track {
	Data zero_pre;			/* pre-gap generated with zero data */
	Data file;			/* track data file */
	Data zero_post;			/* post-gap generated with zero data */
	int mode;			/* track mode */
	int sub_mode;			/* sub-channel mode */
	int flags;			/* flags */
	char *isrc;			/* IRSC Code (5.22.4) 12 bytes */
	Cdtext *cdtext;			/* CD-TEXT */
	int nindex;			/* number of indexes */
	long index[MAXINDEX];		/* indexes (in frames) (5.29.2.5)
					 * relative to start of track
					 * index[0] should always be zero */
};

struct Cd {
	int mode;			/* disc mode */
	char *catalog;			/* Media Catalog Number (5.22.3) */
	Cdtext *cdtext;			/* CD-TEXT */
	int ntrack;			/* number of tracks in album */
	Track *track[MAXTRACK];		/* array of tracks */
};

Cd *cd_init ()
{
	Cd *cd = NULL;
	cd = malloc(sizeof(Cd));

	if(NULL == cd) {
		fprintf(stderr, "unable to create cd\n");
	} else {
		cd->mode = MODE_CD_DA;
		cd->catalog = NULL;
		cd->cdtext = cdtext_init();
		cd->ntrack = 0;
	}

	return cd;
}

void cd_delete(Cd *cd)
{
	int i;
	
	if(NULL !=  cd) {
		if(NULL != cd->catalog) {
			free(cd->catalog);
		}
		
		cdtext_delete(cd->cdtext);
		
		for(i = 0; i < cd->ntrack; ++i) {
			track_delete(cd->track[i]);
		}
		
		free(cd);
	}
}

Track *track_init ()
{
	Track *track = NULL;
	track = malloc(sizeof(Track));

	if (NULL == track) {
		fprintf(stderr, "unable to create track\n");
	} else {
		track->zero_pre.type = DATA_ZERO;
		track->zero_pre.name = NULL;
		track->zero_pre.start = 0;
		track->zero_pre.length = 0;

		track->file.type = DATA_AUDIO;
		track->file.name = NULL;
		track->file.start = 0;
		track->file.length = 0;

		track->zero_post.type = DATA_ZERO;
		track->zero_post.name = NULL;
		track->zero_post.start = 0;
		track->zero_post.length = 0;

		track->mode = MODE_AUDIO;
		track->sub_mode = SUB_MODE_RW;
		track->flags = FLAG_NONE;
		track->isrc = NULL;
		track->cdtext = cdtext_init();
		track->nindex = 0;
	}

	return track;
}

void track_delete(Track *track)
{
	if(NULL != track) {
		if(NULL != track->file.name) {
			free(track->file.name);
		}
		if(NULL != track->isrc) {
			free(track->isrc);
		}
		cdtext_delete(track->cdtext);
		free(track);
	}
}

/*
 * cd structure functions
 */
void cd_set_mode (Cd *cd, int mode)
{
	cd->mode = mode;
}

int cd_get_mode (Cd *cd)
{
	return cd->mode;
}

void cd_set_catalog (Cd *cd, char *catalog)
{
	if (cd->catalog)
		free(cd->catalog);

	cd->catalog = strdup(catalog);
}

char *cd_get_catalog (Cd *cd)
{
	return cd->catalog;
}

Cdtext *cd_get_cdtext (Cd *cd)
{
	return cd->cdtext;
}

Track *cd_add_track (Cd *cd)
{
	if (MAXTRACK - 1 > cd->ntrack)
		cd->ntrack++;
	else
		fprintf(stderr, "too many tracks\n");

	/* this will reinit last track if there were too many */
	cd->track[cd->ntrack - 1] = track_init();

	return cd->track[cd->ntrack - 1];
}


int cd_get_ntrack (Cd *cd)
{
	return cd->ntrack;
}

Track *cd_get_track (Cd *cd, int i)
{
	if (0 < i <= cd->ntrack)
		return cd->track[i - 1];

	return NULL;
}

/*
 * track structure functions
 */

void track_set_filename (Track *track, char *filename)
{
	if (track->file.name)
		free(track->file.name);

	track->file.name = strdup(filename);
}

char *track_get_filename (Track *track)
{
	return track->file.name;
}

void track_set_start (Track *track, long start)
{
	track->file.start = start;
}

long track_get_start (Track *track)
{
	return track->file.start;
}

void track_set_length (Track *track, long length)
{
	track->file.length = length;
}

long track_get_length (Track *track)
{
	return track->file.length;
}

void track_set_mode (Track *track, int mode)
{
	track->mode = mode;
}

int track_get_mode (Track *track)
{
	return track->mode;
}

void track_set_sub_mode (Track *track, int sub_mode)
{
	track->sub_mode = sub_mode;
}

int track_get_sub_mode (Track *track)
{
	return track->sub_mode;
}

void track_set_flag (Track *track, int flag)
{
	track->flags |= flag;
}

void track_clear_flag (Track *track, int flag)
{
	track->flags &= ~flag;
}

int track_is_set_flag (Track *track, int flag)
{
	return track->flags & flag;
}

void track_set_zero_pre (Track *track, long length)
{
	track->zero_pre.length = length;
}

long track_get_zero_pre (Track *track)
{
	return track->zero_pre.length;
}

void track_set_zero_post (Track *track, long length)
{
	track->zero_post.length = length;
}

long track_get_zero_post (Track *track)
{
	return track->zero_post.length;
}
void track_set_isrc (Track *track, char *isrc)
{
	if (track->isrc)
		free(track->isrc);

	track->isrc = strdup(isrc);
}

char *track_get_isrc (Track *track)
{
	return track->isrc;
}

Cdtext *track_get_cdtext (Track *track)
{
	return track->cdtext;
}

void track_add_index (Track *track, long index)
{
	if (MAXTRACK - 1 > track->nindex)
		track->nindex++;
	else
		fprintf(stderr, "too many indexes\n");

	/* this will overwrite last index if there were too many */
	track->index[track->nindex - 1] = index;
}

int track_get_nindex (Track *track)
{
	return track->nindex;
}

long track_get_index (Track *track, int i)
{
	if (0 <= i < track->nindex)
		return track->index[i];

	return -1;
}

/*
 * dump cd information
 */
void cd_track_dump (Track *track)
{
	int i;

	printf("zero_pre: %ld\n", track->zero_pre.length);
	printf("filename: %s\n", track->file.name);
	printf("start: %ld\n", track->file.start);
	printf("length: %ld\n", track->file.length);
	printf("zero_post: %ld\n", track->zero_post.length);
	printf("mode: %d\n", track->mode);
	printf("sub_mode: %d\n", track->sub_mode);
	printf("flags: 0x%x\n", track->flags);
	printf("isrc: %s\n", track->isrc);
	printf("indexes: %d\n", track->nindex);

	for (i = 0; i < track->nindex; ++i)
		printf("index %d: %ld\n", i, track->index[i]);

	if (NULL != track->cdtext) {
		printf("cdtext:\n");
		cdtext_dump(track->cdtext, 1);
	}
}

void cd_dump (Cd *cd)
{
	int i;

	printf("Disc Info\n");
	printf("mode: %d\n", cd->mode);
	printf("catalog: %s\n", cd->catalog);
	if (NULL != cd->cdtext) {
		printf("cdtext:\n");
		cdtext_dump(cd->cdtext, 0);
	}

	for (i = 0; i < cd->ntrack; ++i) {
		printf("Track %d Info\n", i + 1);
		cd_track_dump(cd->track[i]);
	}
}
