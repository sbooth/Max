%{
/*
 * toc_scan.l -- lexer for toc files
 *
 * Copyright (C) 2004, 2005, 2006 Svend Sorensen
 * For license terms, see the file COPYING in this distribution.
 */

#include <stdlib.h>
#include <string.h>
#include "cd.h"
#include "toc_parse_prefix.h"
#include "toc_parse.h"

int toc_lineno = 1;
%}

ws		[ \t\r]
nonws		[^ \t\r\n]

%option noyywrap
%option prefix="toc_yy"

%s NAME

%%

\'([^\']|\\\')*\'	|
\"([^\"]|\\\")*\"	{
		yylval.sval = strdup(yytext + 1);
		yylval.sval[strlen(yylval.sval) - 1] = '\0';
		BEGIN(INITIAL);
		return STRING;
		}

<NAME>{nonws}+	{
		yylval.sval = strdup(yytext);
		BEGIN(INITIAL);
		return STRING;
		}

CATALOG		{ BEGIN(NAME); return CATALOG; }

CD_DA		{ yylval.ival = MODE_CD_DA; return CD_DA; }
CD_ROM		{ yylval.ival = MODE_CD_ROM; return CD_ROM; }
CD_ROM_XA	{ yylval.ival = MODE_CD_ROM_XA; return CD_ROM_XA; }

TRACK		{ return TRACK; }
AUDIO		{ yylval.ival = MODE_AUDIO; return AUDIO; }
MODE1		{ yylval.ival = MODE_MODE1; return MODE1; }
MODE1_RAW	{ yylval.ival = MODE_MODE1_RAW; return MODE1_RAW; }
MODE2		{ yylval.ival = MODE_MODE2; return MODE2; }
MODE2_FORM1	{ yylval.ival = MODE_MODE2_FORM1; return MODE2_FORM1; }
MODE2_FORM2	{ yylval.ival = MODE_MODE2_FORM2; return MODE2_FORM2; }
MODE2_FORM_MIX	{ yylval.ival = MODE_MODE2_FORM_MIX; return MODE2_FORM_MIX; }
MODE2_RAW	{ yylval.ival = MODE_MODE2_RAW; return MODE2_RAW; }
RW		{ yylval.ival = SUB_MODE_RW; return RW; }
RW_RAW		{ yylval.ival = SUB_MODE_RW_RAW; return RW_RAW; }

NO		{ return NO; }
COPY		{ yylval.ival = FLAG_COPY_PERMITTED; return COPY; }
PRE_EMPHASIS	{ yylval.ival = FLAG_PRE_EMPHASIS; return PRE_EMPHASIS; }
FOUR_CHANNEL_AUDIO	{ yylval.ival = FLAG_FOUR_CHANNEL; return FOUR_CHANNEL_AUDIO; }
TWO_CHANNEL_AUDIO	{ yylval.ival = FLAG_FOUR_CHANNEL; return TWO_CHANNEL_AUDIO; }

		/* ISRC is with CD-TEXT items */

SILENCE		{ return SILENCE; }
ZERO		{ return ZERO; }
(AUDIO)?FILE	{ BEGIN(NAME); return AUDIOFILE; }
DATAFILE	{ BEGIN(NAME); return DATAFILE; }
FIFO		{ BEGIN(NAME); return FIFO; }
START		{ return START; }
PREGAP		{ return PREGAP; }
INDEX		{ return INDEX; }

CD_TEXT		{ return CD_TEXT; }
LANGUAGE_MAP	{ return LANGUAGE_MAP; }
LANGUAGE	{ return LANGUAGE; }

TITLE		{ BEGIN(NAME); yylval.ival = PTI_TITLE;  return TITLE; }
PERFORMER	{ BEGIN(NAME); yylval.ival = PTI_PERFORMER;  return PERFORMER; }
SONGWRITER	{ BEGIN(NAME); yylval.ival = PTI_SONGWRITER;  return SONGWRITER; }
COMPOSER	{ BEGIN(NAME); yylval.ival = PTI_COMPOSER;  return COMPOSER; }
ARRANGER	{ BEGIN(NAME); yylval.ival = PTI_ARRANGER;  return ARRANGER; }
MESSAGE		{ BEGIN(NAME); yylval.ival = PTI_MESSAGE;  return MESSAGE; }
DISC_ID		{ BEGIN(NAME); yylval.ival = PTI_DISC_ID;  return DISC_ID; }
GENRE		{ BEGIN(NAME); yylval.ival = PTI_GENRE;  return GENRE; }
TOC_INFO1	{ BEGIN(NAME); yylval.ival = PTI_TOC_INFO1;  return TOC_INFO1; }
TOC_INFO2	{ BEGIN(NAME); yylval.ival = PTI_TOC_INFO2;  return TOC_INFO2; }
UPC_EAN		{ BEGIN(NAME); yylval.ival = PTI_UPC_ISRC;  return UPC_EAN; }
ISRC		{ BEGIN(NAME); yylval.ival = PTI_UPC_ISRC;  return ISRC; }
SIZE_INFO	{ BEGIN(NAME); yylval.ival = PTI_SIZE_INFO;  return SIZE_INFO; }

"//".*\n	{ toc_lineno++; /* ignore comments */ }
{ws}+		{ /* ignore whitespace */ }

[[:digit:]]+	{ yylval.ival = atoi(yytext); return NUMBER; }
:|,|\{|\}	{ return yytext[0]; }

^{ws}*\n	{ toc_lineno++; /* blank line */ }
\n		{ toc_lineno++; return '\n'; }
.		{ fprintf(stderr, "bad character '%c'\n", yytext[0]); }

%%
