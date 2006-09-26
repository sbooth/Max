%{
/*
 * toc_parse.y -- parser for toc files
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "cd.h"
#include "time.h"
#include "toc_parse_prefix.h"

#define YYDEBUG 1

extern int yylex();
void yyerror (char *s);

static Cd *cd = NULL;
static Track *track = NULL;
static Cdtext *cdtext = NULL;
%}

%start tocfile

%union {
	long ival;
	char *sval;
}

%token <ival> NUMBER
%token <sval> STRING

/* global (header) */
%token CATALOG

%token <ival> CD_DA
%token <ival> CD_ROM
%token <ival> CD_ROM_XA

/* track */
%token TRACK
%token <ival> AUDIO	
%token <ival> MODE1	
%token <ival> MODE1_RAW
%token <ival> MODE2	
%token <ival> MODE2_FORM1
%token <ival> MODE2_FORM2
%token <ival> MODE2_FORM_MIX
%token <ival> MODE2_RAW
%token <ival> RW
%token <ival> RW_RAW

%token NO
%token <ival> COPY
%token <ival> PRE_EMPHASIS
%token <ival> TWO_CHANNEL_AUDIO
%token <ival> FOUR_CHANNEL_AUDIO

%token ISRC
%token SILENCE
%token ZERO
%token AUDIOFILE
%token DATAFILE
%token FIFO
%token START
%token PREGAP
%token INDEX

/* CD-TEXT */
%token CD_TEXT
%token LANGUAGE_MAP
%token LANGUAGE

%token <ival> TITLE
%token <ival> PERFORMER
%token <ival> SONGWRITER
%token <ival> COMPOSER
%token <ival> ARRANGER
%token <ival> MESSAGE
%token <ival> DISC_ID
%token <ival> GENRE
%token <ival> TOC_INFO1
%token <ival> TOC_INFO2
%token <ival> UPC_EAN	
%token <ival> ISRC
%token <ival> SIZE_INFO

%type <ival> disc_mode
%type <ival> track_modes
%type <ival> track_mode
%type <ival> track_sub_mode
%type <ival> track_set_flag
%type <ival> track_clear_flag
%type <ival> time
%type <ival> cdtext_item

%%

tocfile
	: new_cd global_statements track_list
	;

new_cd
	: /* empty */ {
		cd = cd_init();
		cdtext = cd_get_cdtext(cd);
	}
	;

global_statements
	: /* empty */
	| global_statements global_statement
	;

global_statement
	: CATALOG STRING '\n' { cd_set_catalog(cd, $2); }
	| disc_mode '\n' { cd_set_mode(cd, $1); }
	| CD_TEXT '{' opt_nl language_map cdtext_langs '}' '\n'
	| error '\n'
	;

disc_mode
	: CD_DA
	| CD_ROM
	| CD_ROM_XA
	;
	
track_list
	: track
	| track_list track
	;

track
	: new_track track_def track_statements {
		while (2 > track_get_nindex(track))
			track_add_index(track, 0);
	}
	;

new_track
	: /* empty */ {
		track = cd_add_track(cd);
		cdtext = track_get_cdtext(track);
		/* add 0 index */
		track_add_index(track, 0);
	}
	;
	
track_def
	: TRACK track_modes '\n' { track_set_mode(track, $2); }
	;

track_modes
	: track_mode
	| track_mode track_sub_mode { track_set_sub_mode(track, $2); }
	;

track_mode
	: AUDIO
	| MODE1
	| MODE1_RAW
	| MODE2
	| MODE2_FORM1
	| MODE2_FORM2
	| MODE2_FORM_MIX
	| MODE2_RAW
	;

track_sub_mode	
	: RW
	| RW_RAW
	;

track_statements
	: track_statement
	| track_statements track_statement
	;

track_statement
	: track_flags
	| ISRC STRING '\n' { track_set_isrc(track, $2); }
	| CD_TEXT '{' opt_nl cdtext_langs '}' '\n'
	| track_data
	| track_pregap
	| track_index
	| error '\n'
	;

track_flags
	: track_set_flag { track_set_flag(track, $1); }
	| track_clear_flag { track_clear_flag(track, $1); }
	;

track_set_flag
	: COPY '\n'
	| PRE_EMPHASIS '\n'
	| FOUR_CHANNEL_AUDIO '\n'
	;

track_clear_flag
	: NO PRE_EMPHASIS '\n' { $$ = $2; }
	| NO COPY '\n' { $$ = $2; }
	| TWO_CHANNEL_AUDIO '\n'
	;

track_data
	: zero_data time '\n' {
		if (NULL == track_get_filename(track))
			track_set_zero_pre(track, $2);
		else
			track_set_zero_post(track, $2);
	}
	| AUDIOFILE STRING time '\n' {
		track_set_filename(track, $2);
		track_set_start(track, $3);
	}
	| AUDIOFILE STRING time time '\n' {
		track_set_filename(track, $2);
		track_set_start(track, $3);
		track_set_length(track, $4);
	}
	| DATAFILE STRING '\n' {
		track_set_filename(track, $2);
	}
	| DATAFILE STRING time '\n' {
		track_set_filename(track, $2);
		track_set_start(track, $3);
	}
	| FIFO STRING time '\n' {
		track_set_filename(track, $2);
		track_set_start(track, $3);
	}
	;

zero_data
	: SILENCE
	| ZERO
	;

track_pregap
	: START '\n'
	| START time '\n' {
		track_add_index(track, $2);
	}
	| PREGAP time '\n' {
		track_set_zero_pre(track, $2);
		track_add_index(track, $2);
	}
	;

track_index
	: INDEX time '\n' { track_add_index(track, $2); }
	;

language_map
	: LANGUAGE_MAP '{' opt_nl languages '}' '\n'
	;

languages
	: language
	| languages language
	;

language
	: NUMBER ':' NUMBER opt_nl { /* not implemented */ }
	;

cdtext_langs
	: cdtext_lang
	| cdtext_langs cdtext_lang
	;

cdtext_lang
	: LANGUAGE NUMBER '{' opt_nl cdtext_defs '}' '\n'
	;

cdtext_defs
	: /* empty */
	| cdtext_defs cdtext_def
	;

cdtext_def
	: cdtext_item STRING '\n' {
		cdtext_set ($1, $2, cdtext);
	}
	| cdtext_item '{' bytes '}' '\n' {
		yyerror("binary CD-TEXT data not supported\n");
	}
	;

cdtext_item
	: TITLE
	| PERFORMER
	| SONGWRITER
	| COMPOSER
	| ARRANGER
	| MESSAGE
	| DISC_ID
	| GENRE
	| TOC_INFO1
	| TOC_INFO2
	| UPC_EAN
	| ISRC
	| SIZE_INFO
	;

bytes
	: /* empty */
	| bytes ',' NUMBER
	;

time
	: NUMBER
	| NUMBER ':' NUMBER ':' NUMBER { $$ = time_msf_to_frame($1, $3, $5); }
	;

opt_nl
	: /* empty */
	| '\n'
	;

%%

/* lexer interface */
extern int toc_lineno;
extern int yydebug;
extern FILE *toc_yyin;

void yyerror (char *s)
{
	fprintf(stderr, "%d: %s\n", toc_lineno, s);
}

Cd *toc_parse (FILE *fp)
{
	toc_yyin = fp;
	yydebug = 0;

	if (0 == yyparse())
		return cd;

	return NULL;
}
