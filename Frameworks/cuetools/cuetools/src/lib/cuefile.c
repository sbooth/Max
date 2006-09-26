/*
 * cuefile.c -- cue/toc functions
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdlib.h>
#include <string.h>
#include "cuefile.h"
#include "cue.h"
#include "toc.h"

Cd *cf_parse (char *name, int *format)
{
	FILE *fp = NULL;
	Cd *cd = NULL;

	if (UNKNOWN == *format)
		if (UNKNOWN == (*format = cf_format_from_suffix(name))) {
			fprintf(stderr, "%s: unknown format\n", name);
			return NULL;
		}

	if (0 == strcmp("-", name)) {
		fp = stdin;
	} else if (NULL == (fp = fopen(name, "r"))) {
		fprintf(stderr, "%s: error opening file\n", name);
		return NULL;
	}

	switch (*format) {
	case CUE:
		cd = cue_parse(fp);
		break;
	case TOC:
		cd = toc_parse(fp);
		break;
	}

	if(stdin != fp)
		fclose(fp);

	return cd;
}

int cf_print (char *name, int *format, Cd *cd)
{
	FILE *fp = NULL;

	if (UNKNOWN == *format)
		if (UNKNOWN == (*format = cf_format_from_suffix(name))) {
			fprintf(stderr, "%s: unknown format\n", name);
			return -1;
		}

	if (0 == strcmp("-", name)) {
		fp = stdout;
	} else if (NULL == (fp = fopen(name, "w"))) {
		fprintf(stderr, "%s: error opening file\n", name);
		return -1;
	}
	
	switch (*format) {
	case CUE:
		cue_print(fp, cd);
		break;
	case TOC:
		toc_print(fp, cd);
		break;
	}

	if(stdout != fp)
		fclose(fp);

	return 0;
}

int cf_format_from_suffix (char *name)
{
	char *suffix;
	if (0 != (suffix = strrchr(name, '.'))) {
		if (0 == strcasecmp(".cue", suffix))
			return CUE;
		else if (0 == strcasecmp(".toc", suffix))
			return TOC;
	}

	return UNKNOWN;
}
