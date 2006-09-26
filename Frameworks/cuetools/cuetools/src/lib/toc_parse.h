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
     CD_DA = 261,
     CD_ROM = 262,
     CD_ROM_XA = 263,
     TRACK = 264,
     AUDIO = 265,
     MODE1 = 266,
     MODE1_RAW = 267,
     MODE2 = 268,
     MODE2_FORM1 = 269,
     MODE2_FORM2 = 270,
     MODE2_FORM_MIX = 271,
     MODE2_RAW = 272,
     RW = 273,
     RW_RAW = 274,
     NO = 275,
     COPY = 276,
     PRE_EMPHASIS = 277,
     TWO_CHANNEL_AUDIO = 278,
     FOUR_CHANNEL_AUDIO = 279,
     ISRC = 280,
     SILENCE = 281,
     ZERO = 282,
     AUDIOFILE = 283,
     DATAFILE = 284,
     FIFO = 285,
     START = 286,
     PREGAP = 287,
     INDEX = 288,
     CD_TEXT = 289,
     LANGUAGE_MAP = 290,
     LANGUAGE = 291,
     TITLE = 292,
     PERFORMER = 293,
     SONGWRITER = 294,
     COMPOSER = 295,
     ARRANGER = 296,
     MESSAGE = 297,
     DISC_ID = 298,
     GENRE = 299,
     TOC_INFO1 = 300,
     TOC_INFO2 = 301,
     UPC_EAN = 302,
     SIZE_INFO = 303
   };
#endif
#define NUMBER 258
#define STRING 259
#define CATALOG 260
#define CD_DA 261
#define CD_ROM 262
#define CD_ROM_XA 263
#define TRACK 264
#define AUDIO 265
#define MODE1 266
#define MODE1_RAW 267
#define MODE2 268
#define MODE2_FORM1 269
#define MODE2_FORM2 270
#define MODE2_FORM_MIX 271
#define MODE2_RAW 272
#define RW 273
#define RW_RAW 274
#define NO 275
#define COPY 276
#define PRE_EMPHASIS 277
#define TWO_CHANNEL_AUDIO 278
#define FOUR_CHANNEL_AUDIO 279
#define ISRC 280
#define SILENCE 281
#define ZERO 282
#define AUDIOFILE 283
#define DATAFILE 284
#define FIFO 285
#define START 286
#define PREGAP 287
#define INDEX 288
#define CD_TEXT 289
#define LANGUAGE_MAP 290
#define LANGUAGE 291
#define TITLE 292
#define PERFORMER 293
#define SONGWRITER 294
#define COMPOSER 295
#define ARRANGER 296
#define MESSAGE 297
#define DISC_ID 298
#define GENRE 299
#define TOC_INFO1 300
#define TOC_INFO2 301
#define UPC_EAN 302
#define SIZE_INFO 303




#if ! defined (YYSTYPE) && ! defined (YYSTYPE_IS_DECLARED)
#line 28 "toc_parse.y"
typedef union YYSTYPE {
	long ival;
	char *sval;
} YYSTYPE;
/* Line 1249 of yacc.c.  */
#line 137 "toc_parse.h"
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif

extern YYSTYPE yylval;



