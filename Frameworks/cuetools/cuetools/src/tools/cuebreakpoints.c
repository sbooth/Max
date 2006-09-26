/*
 * cuebreakpoints.c -- print track break points
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include "cuefile.h"
#include "time.h"

char *progname;

/* pregap correction modes
 * APPEND - append pregap to previous track (except for first track)
 * PREPEND - prefix pregap to current track
 * SPLIT - print breakpoints for beginning and end of pregap
 */
enum GapMode {APPEND, PREPEND, SPLIT};

void usage (int status)
{
	if (0 == status) {
		fprintf(stdout, "%s: usage: cuebreakpoints [option...] [file...]\n", progname);
		fputs("\
\n\
OPTIONS\n\
-h, --help			print usage\n\
-i, --input-format cue|toc	set format of file(s)\n\
--append-gaps			append pregaps to previous track (default)\n\
--prepend-gaps			prefix pregaps to track\n\
--split-gaps			split at beginning and end of pregaps\n\
", stdout);
	} else {
		fprintf(stderr, "run `%s --help' for usage\n", progname);
	}

	exit (status);
}

void print_m_ss_ff (long frame)
{
	int m, s, f;

	time_frame_to_msf(frame, &m, &s, &f);
	printf ("%d:%02d.%02d\n", m, s, f);
}

void print_breakpoint (long b)
{
	/* do not print zero breakpoints */
	if (0 != b)
		print_m_ss_ff(b);
}

void print_breaks (Cd *cd, int gaps)
{
	int i;
	long b;
	long pg;
	Track *track;

	for (i = 1; i <= cd_get_ntrack(cd); i++) {
		track = cd_get_track(cd, i);
		/* when breakpoint is at:
		 * index 0: gap is prepended to track
		 * index 1: gap is appended to previous track
		 */
		b = track_get_start(track);
		pg = track_get_index(track, 1) - track_get_zero_pre(track);

		if (gaps == PREPEND || gaps == SPLIT) {
			print_breakpoint(b);
		/* there is no previous track to append the first tracks pregap to */
		} else if (gaps == APPEND && 1 < i) {
			print_breakpoint(b + pg);
		}

		/* if pregap exists, print breakpoints (in split mode) */
		if (gaps == SPLIT && 0 < pg) {
			print_breakpoint(b + pg);
		}
	}
}

int breaks (char *name, int format, int gaps)
{
	Cd *cd = NULL;

	if (NULL == (cd = cf_parse(name, &format))) {
		fprintf(stderr, "%s: input file error\n", name);
		return -1;
	}

	print_breaks(cd, gaps);

	return 0;
}

int main (int argc, char **argv)
{
	int format = UNKNOWN;
	int gaps = APPEND;

	/* option variables */
	char c;
	/* getopt_long() variables */
	extern char *optarg;
	extern int optind;

	static struct option longopts[] = {
		{"help", no_argument, NULL, 'h'},
		{"input-format", required_argument, NULL, 'i'},
		{"append-gaps", no_argument, NULL, 'a'},
		{"prepend-gaps", no_argument, NULL, 'p'},
		{"split-gaps", no_argument, NULL, 's'},
		{NULL, 0, NULL, 0}
	};

	progname = *argv;

	while (-1 != (c = getopt_long(argc, argv, "hi:", longopts, NULL))) {
		switch (c) {
		case 'h':
			usage(0);
			break;
		case 'i':
			if (0 == strcmp("cue", optarg)) {
				format = CUE;
			} else if (0 == strcmp("toc", optarg)) {
				format = TOC;
			} else {
				fprintf(stderr, "%s: illegal format `%s'\n", progname, optarg);
				usage(1);
			}
			break;
		case 'a':
			gaps = APPEND;
			break;
		case 'p':
			gaps = PREPEND;
			break;
		case 's':
			gaps = SPLIT;
			break;
		default:
			usage(1);
			break;
		}
	}

	if (optind == argc) {
		breaks("-", format, gaps);
	} else {
		for (; optind < argc; optind++)
			breaks(argv[optind], format, gaps);
	}

	return 0;
}
