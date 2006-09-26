/* A Bison parser, made by GNU Bison 1.875.  */

/* Skeleton parser for Yacc-like parsing with Bison,
   Copyright (C) 1984, 1989, 1990, 2000, 2001, 2002 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.  */

/* As a special exception, when this file is copied by Bison into a
   Bison output file, you may use that output file without restriction.
   This special exception was added by the Free Software Foundation
   in version 1.24 of Bison.  */

/* Tokens.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
   /* Put the tokens into the symbol table, so that GDB and other debuggers
      know about them.  */
   enum yytokentype {
     NUMBER = 258,
     STRING = 259,
     CATALOG = 260,
     CDTEXTFILE = 261,
     FFILE = 262,
     BINARY = 263,
     MOTOROLA = 264,
     AIFF = 265,
     WAVE = 266,
     MP3 = 267,
     TRACK = 268,
     AUDIO = 269,
     MODE1_2048 = 270,
     MODE1_2352 = 271,
     MODE2_2336 = 272,
     MODE2_2048 = 273,
     MODE2_2342 = 274,
     MODE2_2332 = 275,
     MODE2_2352 = 276,
     TRACK_ISRC = 277,
     FLAGS = 278,
     PRE = 279,
     DCP = 280,
     FOUR_CH = 281,
     SCMS = 282,
     PREGAP = 283,
     INDEX = 284,
     POSTGAP = 285,
     TITLE = 286,
     PERFORMER = 287,
     SONGWRITER = 288,
     COMPOSER = 289,
     ARRANGER = 290,
     MESSAGE = 291,
     DISC_ID = 292,
     GENRE = 293,
     TOC_INFO1 = 294,
     TOC_INFO2 = 295,
     UPC_EAN = 296,
     ISRC = 297,
     SIZE_INFO = 298
   };
#endif
#define NUMBER 258
#define STRING 259
#define CATALOG 260
#define CDTEXTFILE 261
#define FFILE 262
#define BINARY 263
#define MOTOROLA 264
#define AIFF 265
#define WAVE 266
#define MP3 267
#define TRACK 268
#define AUDIO 269
#define MODE1_2048 270
#define MODE1_2352 271
#define MODE2_2336 272
#define MODE2_2048 273
#define MODE2_2342 274
#define MODE2_2332 275
#define MODE2_2352 276
#define TRACK_ISRC 277
#define FLAGS 278
#define PRE 279
#define DCP 280
#define FOUR_CH 281
#define SCMS 282
#define PREGAP 283
#define INDEX 284
#define POSTGAP 285
#define TITLE 286
#define PERFORMER 287
#define SONGWRITER 288
#define COMPOSER 289
#define ARRANGER 290
#define MESSAGE 291
#define DISC_ID 292
#define GENRE 293
#define TOC_INFO1 294
#define TOC_INFO2 295
#define UPC_EAN 296
#define ISRC 297
#define SIZE_INFO 298




#if ! defined (YYSTYPE) && ! defined (YYSTYPE_IS_DECLARED)
#line 32 "cue_parse.y"
typedef union YYSTYPE {
	long ival;
	char *sval;
} YYSTYPE;
/* Line 1249 of yacc.c.  */
#line 127 "cue_parse.h"
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif

extern YYSTYPE yylval;



