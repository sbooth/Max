/*
 * cue_print.y -- print cue file
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdio.h>
#include <string.h>
#include "cd.h"
#include "time.h"

void cue_print_track (FILE *fp, Track *track, int trackno);
void cue_print_cdtext (Cdtext *cdtext, FILE *fp, int istrack);
void cue_print_index (long i, FILE *fp);
char *filename = "";	/* last track datafile */
long prev_length = 0;	/* last track length */

/* prints cd in cue format */
void cue_print (FILE *fp, Cd *cd)
{
	Cdtext *cdtext = cd_get_cdtext(cd);
	int i; 	/* track */
	Track *track = NULL;

	/* print global information */
	if (NULL != cd_get_catalog(cd))
		fprintf(fp, "CATALOG %s\n", cd_get_catalog(cd));

	cue_print_cdtext(cdtext, fp, 0);

	/* print track information */
	for (i = 1; i <= cd_get_ntrack(cd); i++) {
		track = cd_get_track(cd, i);
		fprintf(fp, "\n");
		cue_print_track(fp, track, i);
	}
}

void cue_print_track (FILE *fp, Track *track, int trackno)
{
	Cdtext *cdtext = track_get_cdtext(track);
	int i; 	/* index */

	if (NULL != track_get_filename(track)) {
		/*
		 * always print filename for track 1, afterwards only
		 * print filename if it differs from the previous track
		 */
		if (0 != strcmp(track_get_filename(track), filename)) {
			filename = track_get_filename(track);
			fprintf(fp, "FILE \"%s\" ", filename);

			/* NOTE: what to do with other formats (MP3, etc)? */
			if (MODE_AUDIO == track_get_mode(track))
				fprintf(fp, "WAVE\n");
			else
				fprintf(fp, "BINARY\n");
		}
	}

	fprintf(fp, "TRACK %02d ", trackno);
	switch (track_get_mode(track)) {
	case MODE_AUDIO:
		fprintf(fp, "AUDIO\n");
		break;
	case MODE_MODE1:
		fprintf(fp, "MODE1/2048\n");
		break;
	case MODE_MODE1_RAW:
		fprintf(fp, "MODE1/2352\n");
		break;
	case MODE_MODE2:
		fprintf(fp, "MODE2/2048\n");
		break;
	case MODE_MODE2_FORM1:
		fprintf(fp, "MODE2/2336\n");
		break;
	case MODE_MODE2_FORM2:
		fprintf(fp, "MODE2/2324\n");
		break;
	case MODE_MODE2_FORM_MIX:
		fprintf(fp, "MODE2/2336\n");
		break;
	case MODE_MODE2_RAW:
		fprintf(fp, "MODE2/2352\n");
		break;
	}

	cue_print_cdtext(cdtext, fp, 1);

	if (0 != track_is_set_flag(track, FLAG_ANY)) {
		fprintf(fp, "FLAGS");
		if (0 != track_is_set_flag(track, FLAG_PRE_EMPHASIS))
			fprintf(fp, " PRE");
		if (0 != track_is_set_flag(track, FLAG_COPY_PERMITTED))
			fprintf(fp, " DCP");
		if (0 != track_is_set_flag(track, FLAG_FOUR_CHANNEL))
			fprintf(fp, " 4CH");
		if (0 != track_is_set_flag(track, FLAG_SCMS))
			fprintf(fp, " SCMS");
		fprintf(fp, "\n");
	}

	if (NULL != track_get_isrc(track))
		fprintf(fp, "ISRC %s\n", track_get_isrc(track));

	if (0 != track_get_zero_pre(track))
		fprintf (fp, "PREGAP %s\n", time_frame_to_mmssff(track_get_zero_pre(track)));

	/* don't print index 0 if index 1 = 0 */
	if (track_get_index(track, 1) == 0)
		i = 1;
	else
		i = 0;

	for (; i < track_get_nindex(track); i++) {
		fprintf(fp, "INDEX %02d ", i);
		cue_print_index( \
		track_get_index(track, i) \
		+ track_get_start(track) \
		- track_get_zero_pre(track) , fp);
	}

	if (0 != track_get_zero_post(track))
		fprintf (fp, "POSTGAP %s\n", time_frame_to_mmssff(track_get_zero_post(track)));

	prev_length = track_get_length(track);
}

void cue_print_cdtext (Cdtext *cdtext, FILE *fp, int istrack)
{
	int pti;
	char *value = NULL;

	for (pti = 0; PTI_END != pti; pti++) {
		if (NULL != (value = cdtext_get(pti, cdtext))) {
			fprintf(fp, "%s", cdtext_get_key(pti, istrack));
			fprintf(fp, " \"%s\"\n", value);
		}
	}
}

void cue_print_index (long i, FILE *fp)
{
	fprintf (fp, "%s\n", time_frame_to_mmssff(i));
}
