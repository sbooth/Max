/*
 * toc_print.c -- print toc file
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdio.h>
#include <string.h>
#include "cd.h"
#include "time.h"

void toc_print_track (FILE *fp, Track *track);
void toc_print_cdtext (Cdtext *cdtext, FILE *fp, int istrack);

void toc_print (FILE *fp, Cd *cd)
{
	Cdtext *cdtext = cd_get_cdtext(cd);
	int i; 	/* track */
	Track *track;

	switch(cd_get_mode(cd)) {
	case MODE_CD_DA:
		fprintf(fp, "CD_DA\n");
	       	break;
	case MODE_CD_ROM:
		fprintf(fp, "CD_ROM\n");
	       	break;
	case MODE_CD_ROM_XA:
		fprintf(fp, "CD_ROM_XA\n");
	       	break;
	}

	if (NULL != cd_get_catalog(cd))
		fprintf(fp, "CATALOG \"%s\"\n", cd_get_catalog(cd));

	if(0 != cdtext_is_empty(cdtext)) {
		fprintf(fp, "CD_TEXT {\n");
		fprintf(fp, "\tLANGUAGE_MAP { 0:9 }\n");
		fprintf(fp, "\tLANGUAGE 0 {\n");
		toc_print_cdtext(cdtext, fp, 0);
		fprintf(fp, "\t}\n");
		fprintf(fp, "}\n");
	}

	for (i = 1; i <= cd_get_ntrack(cd); i++) {
		track = cd_get_track(cd, i);
		fprintf(fp, "\n");
		toc_print_track(fp, track);
	}
}

void toc_print_track (FILE *fp, Track *track)
{
	Cdtext *cdtext = track_get_cdtext(track);
	int i;	/* index */

	fprintf(fp, "TRACK ");
	switch (track_get_mode(track)) {
	case MODE_AUDIO:
		fprintf(fp, "AUDIO");
	       	break;
	case MODE_MODE1:
		fprintf(fp, "MODE1");
	       	break;
	case MODE_MODE1_RAW:
		fprintf(fp, "MODE1_RAW");
	       	break;
	case MODE_MODE2:
		fprintf(fp, "MODE2");
	       	break;
	case MODE_MODE2_FORM1:
		fprintf(fp, "MODE2_FORM1");
	       	break;
	case MODE_MODE2_FORM2:
		fprintf(fp, "MODE2_FORM2");
	       	break;
	case MODE_MODE2_FORM_MIX:
		fprintf(fp, "MODE2_FORM_MIX");
	       	break;
	}
	fprintf(fp, "\n");

	if (0 != track_is_set_flag(track, FLAG_PRE_EMPHASIS))
		fprintf(fp, "PRE_EMPHASIS\n");
	if (0 != track_is_set_flag(track, FLAG_COPY_PERMITTED))
		fprintf(fp, "COPY\n");
	if (0 != track_is_set_flag(track, FLAG_FOUR_CHANNEL))
		fprintf(fp, "FOUR_CHANNEL_AUDIO\n");

	if (NULL != track_get_isrc(track))
		fprintf(fp, "ISRC \"%s\"\n", track_get_isrc(track));

	if (0 != cdtext_is_empty(cdtext)) {
		fprintf(fp, "CD_TEXT {\n");
		fprintf(fp, "\tLANGUAGE 0 {\n");
		toc_print_cdtext(cdtext, fp, 1);
		fprintf(fp, "\t}\n");
		fprintf(fp, "}\n");
	}

	if (0 != track_get_zero_pre(track)) {
		fprintf(fp, "ZERO ");
		fprintf(fp, "%s", time_frame_to_mmssff(track_get_zero_pre(track)));
		fprintf(fp, "\n");
	}
		
	fprintf(fp, "FILE ");
	fprintf(fp, "\"%s\" ", track_get_filename(track));
	if (0 == track_get_start(track))
		fprintf(fp, "0");
	else
		fprintf(fp, "%s", time_frame_to_mmssff(track_get_start(track)));
	if (0 != track_get_length(track))
		fprintf(fp, " %s", time_frame_to_mmssff(track_get_length(track)));
	fprintf(fp, "\n");

	if (0 != track_get_zero_post(track)) {
		fprintf(fp, "ZERO ");
		fprintf(fp, "%s", time_frame_to_mmssff(track_get_zero_post(track)));
		fprintf(fp, "\n");
	}
		
	if (track_get_index(track, 1) != 0) {
		fprintf(fp, "START ");
		fprintf(fp, "%s\n", time_frame_to_mmssff(track_get_index(track, 1)));
	}

	for (i = 2; i < track_get_nindex(track); i++) {
		fprintf(fp, "INDEX ");
		fprintf(fp, "%s\n", time_frame_to_mmssff( \
		track_get_index(track, i) - track_get_index(track, 0) \
		));
	}
}

void toc_print_cdtext (Cdtext *cdtext, FILE *fp, int istrack)
{
	int pti;
	char *value = NULL;

	for (pti = 0; PTI_END != pti; pti++) {
		if (NULL != (value = cdtext_get(pti, cdtext))) {
			fprintf(fp, "\t\t");
			fprintf(fp, "%s", cdtext_get_key(pti, istrack));
			fprintf(fp, " \"%s\"\n", value);
		}
	}
}
