/*
 * cue.h -- cue function declarations
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

Cd *cue_parse (FILE *fp);
void cue_print (FILE *fp, Cd *cd);
