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

/* Written by Richard Stallman by simplifying the original so called
   ``semantic'' parser.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output.  */
#define YYBISON 1

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Using locations.  */
#define YYLSP_NEEDED 0



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




/* Copy the first part of user declarations.  */
#line 1 "toc_parse.y"

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


/* Enabling traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif

/* Enabling verbose error messages.  */
#ifdef YYERROR_VERBOSE
# undef YYERROR_VERBOSE
# define YYERROR_VERBOSE 1
#else
# define YYERROR_VERBOSE 0
#endif

#if ! defined (YYSTYPE) && ! defined (YYSTYPE_IS_DECLARED)
#line 28 "toc_parse.y"
typedef union YYSTYPE {
	long ival;
	char *sval;
} YYSTYPE;
/* Line 191 of yacc.c.  */
#line 201 "toc_parse.c"
# define yystype YYSTYPE /* obsolescent; will be withdrawn */
# define YYSTYPE_IS_DECLARED 1
# define YYSTYPE_IS_TRIVIAL 1
#endif



/* Copy the second part of user declarations.  */


/* Line 214 of yacc.c.  */
#line 213 "toc_parse.c"

#if ! defined (yyoverflow) || YYERROR_VERBOSE

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# if YYSTACK_USE_ALLOCA
#  define YYSTACK_ALLOC alloca
# else
#  ifndef YYSTACK_USE_ALLOCA
#   if defined (alloca) || defined (_ALLOCA_H)
#    define YYSTACK_ALLOC alloca
#   else
#    ifdef __GNUC__
#     define YYSTACK_ALLOC __builtin_alloca
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's `empty if-body' warning. */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
# else
#  if defined (__STDC__) || defined (__cplusplus)
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   define YYSIZE_T size_t
#  endif
#  define YYSTACK_ALLOC malloc
#  define YYSTACK_FREE free
# endif
#endif /* ! defined (yyoverflow) || YYERROR_VERBOSE */


#if (! defined (yyoverflow) \
     && (! defined (__cplusplus) \
	 || (YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  short yyss;
  YYSTYPE yyvs;
  };

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (sizeof (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (sizeof (short) + sizeof (YYSTYPE))				\
      + YYSTACK_GAP_MAXIMUM)

/* Copy COUNT objects from FROM to TO.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if 1 < __GNUC__
#   define YYCOPY(To, From, Count) \
      __builtin_memcpy (To, From, (Count) * sizeof (*(From)))
#  else
#   define YYCOPY(To, From, Count)		\
      do					\
	{					\
	  register YYSIZE_T yyi;		\
	  for (yyi = 0; yyi < (Count); yyi++)	\
	    (To)[yyi] = (From)[yyi];		\
	}					\
      while (0)
#  endif
# endif

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack)					\
    do									\
      {									\
	YYSIZE_T yynewbytes;						\
	YYCOPY (&yyptr->Stack, Stack, yysize);				\
	Stack = &yyptr->Stack;						\
	yynewbytes = yystacksize * sizeof (*Stack) + YYSTACK_GAP_MAXIMUM; \
	yyptr += yynewbytes / sizeof (*yyptr);				\
      }									\
    while (0)

#endif

#if defined (__STDC__) || defined (__cplusplus)
   typedef signed char yysigned_char;
#else
   typedef short yysigned_char;
#endif

/* YYFINAL -- State number of the termination state. */
#define YYFINAL  3
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   149

/* YYNTOKENS -- Number of terminals. */
#define YYNTOKENS  54
/* YYNNTS -- Number of nonterminals. */
#define YYNNTS  33
/* YYNRULES -- Number of rules. */
#define YYNRULES  88
/* YYNRULES -- Number of states. */
#define YYNSTATES  156

/* YYTRANSLATE(YYLEX) -- Bison symbol number corresponding to YYLEX.  */
#define YYUNDEFTOK  2
#define YYMAXUTOK   303

#define YYTRANSLATE(YYX) 						\
  ((unsigned int) (YYX) <= YYMAXUTOK ? yytranslate[YYX] : YYUNDEFTOK)

/* YYTRANSLATE[YYLEX] -- Bison symbol number corresponding to YYLEX.  */
static const unsigned char yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
      49,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,    53,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,    52,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,    50,     2,    51,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39,    40,    41,    42,    43,    44,
      45,    46,    47,    48
};

#if YYDEBUG
/* YYPRHS[YYN] -- Index of the first RHS symbol of rule number YYN in
   YYRHS.  */
static const unsigned short yyprhs[] =
{
       0,     0,     3,     7,     8,     9,    12,    16,    19,    27,
      30,    32,    34,    36,    38,    41,    45,    46,    50,    52,
      55,    57,    59,    61,    63,    65,    67,    69,    71,    73,
      75,    77,    80,    82,    86,    93,    95,    97,    99,   102,
     104,   106,   109,   112,   115,   119,   123,   126,   130,   135,
     141,   145,   150,   155,   157,   159,   162,   166,   170,   174,
     181,   183,   186,   191,   193,   196,   204,   205,   208,   212,
     218,   220,   222,   224,   226,   228,   230,   232,   234,   236,
     238,   240,   242,   244,   245,   249,   251,   257,   258
};

/* YYRHS -- A `-1'-separated list of the rules' RHS. */
static const yysigned_char yyrhs[] =
{
      55,     0,    -1,    56,    57,    60,    -1,    -1,    -1,    57,
      58,    -1,     5,     4,    49,    -1,    59,    49,    -1,    34,
      50,    86,    76,    79,    51,    49,    -1,     1,    49,    -1,
       6,    -1,     7,    -1,     8,    -1,    61,    -1,    60,    61,
      -1,    62,    63,    67,    -1,    -1,     9,    64,    49,    -1,
      65,    -1,    65,    66,    -1,    10,    -1,    11,    -1,    12,
      -1,    13,    -1,    14,    -1,    15,    -1,    16,    -1,    17,
      -1,    18,    -1,    19,    -1,    68,    -1,    67,    68,    -1,
      69,    -1,    25,     4,    49,    -1,    34,    50,    86,    79,
      51,    49,    -1,    72,    -1,    74,    -1,    75,    -1,     1,
      49,    -1,    70,    -1,    71,    -1,    21,    49,    -1,    22,
      49,    -1,    24,    49,    -1,    20,    22,    49,    -1,    20,
      21,    49,    -1,    23,    49,    -1,    73,    85,    49,    -1,
      28,     4,    85,    49,    -1,    28,     4,    85,    85,    49,
      -1,    29,     4,    49,    -1,    29,     4,    85,    49,    -1,
      30,     4,    85,    49,    -1,    26,    -1,    27,    -1,    31,
      49,    -1,    31,    85,    49,    -1,    32,    85,    49,    -1,
      33,    85,    49,    -1,    35,    50,    86,    77,    51,    49,
      -1,    78,    -1,    77,    78,    -1,     3,    52,     3,    86,
      -1,    80,    -1,    79,    80,    -1,    36,     3,    50,    86,
      81,    51,    49,    -1,    -1,    81,    82,    -1,    83,     4,
      49,    -1,    83,    50,    84,    51,    49,    -1,    37,    -1,
      38,    -1,    39,    -1,    40,    -1,    41,    -1,    42,    -1,
      43,    -1,    44,    -1,    45,    -1,    46,    -1,    47,    -1,
      25,    -1,    48,    -1,    -1,    84,    53,     3,    -1,     3,
      -1,     3,    52,     3,    52,     3,    -1,    -1,    49,    -1
};

/* YYRLINE[YYN] -- source line where rule number YYN was defined.  */
static const unsigned short yyrline[] =
{
       0,   103,   103,   107,   113,   115,   119,   120,   121,   122,
     126,   127,   128,   132,   133,   137,   144,   153,   157,   158,
     162,   163,   164,   165,   166,   167,   168,   169,   173,   174,
     178,   179,   183,   184,   185,   186,   187,   188,   189,   193,
     194,   198,   199,   200,   204,   205,   206,   210,   216,   220,
     225,   228,   232,   239,   240,   244,   245,   248,   255,   259,
     263,   264,   268,   272,   273,   277,   280,   282,   286,   289,
     295,   296,   297,   298,   299,   300,   301,   302,   303,   304,
     305,   306,   307,   310,   312,   316,   317,   320,   322
};
#endif

#if YYDEBUG || YYERROR_VERBOSE
/* YYTNME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals. */
static const char *const yytname[] =
{
  "$end", "error", "$undefined", "NUMBER", "STRING", "CATALOG", "CD_DA", 
  "CD_ROM", "CD_ROM_XA", "TRACK", "AUDIO", "MODE1", "MODE1_RAW", "MODE2", 
  "MODE2_FORM1", "MODE2_FORM2", "MODE2_FORM_MIX", "MODE2_RAW", "RW", 
  "RW_RAW", "NO", "COPY", "PRE_EMPHASIS", "TWO_CHANNEL_AUDIO", 
  "FOUR_CHANNEL_AUDIO", "ISRC", "SILENCE", "ZERO", "AUDIOFILE", 
  "DATAFILE", "FIFO", "START", "PREGAP", "INDEX", "CD_TEXT", 
  "LANGUAGE_MAP", "LANGUAGE", "TITLE", "PERFORMER", "SONGWRITER", 
  "COMPOSER", "ARRANGER", "MESSAGE", "DISC_ID", "GENRE", "TOC_INFO1", 
  "TOC_INFO2", "UPC_EAN", "SIZE_INFO", "'\\n'", "'{'", "'}'", "':'", 
  "','", "$accept", "tocfile", "new_cd", "global_statements", 
  "global_statement", "disc_mode", "track_list", "track", "new_track", 
  "track_def", "track_modes", "track_mode", "track_sub_mode", 
  "track_statements", "track_statement", "track_flags", "track_set_flag", 
  "track_clear_flag", "track_data", "zero_data", "track_pregap", 
  "track_index", "language_map", "languages", "language", "cdtext_langs", 
  "cdtext_lang", "cdtext_defs", "cdtext_def", "cdtext_item", "bytes", 
  "time", "opt_nl", 0
};
#endif

# ifdef YYPRINT
/* YYTOKNUM[YYLEX-NUM] -- Internal token number corresponding to
   token YYLEX-NUM.  */
static const unsigned short yytoknum[] =
{
       0,   256,   257,   258,   259,   260,   261,   262,   263,   264,
     265,   266,   267,   268,   269,   270,   271,   272,   273,   274,
     275,   276,   277,   278,   279,   280,   281,   282,   283,   284,
     285,   286,   287,   288,   289,   290,   291,   292,   293,   294,
     295,   296,   297,   298,   299,   300,   301,   302,   303,    10,
     123,   125,    58,    44
};
# endif

/* YYR1[YYN] -- Symbol number of symbol that rule YYN derives.  */
static const unsigned char yyr1[] =
{
       0,    54,    55,    56,    57,    57,    58,    58,    58,    58,
      59,    59,    59,    60,    60,    61,    62,    63,    64,    64,
      65,    65,    65,    65,    65,    65,    65,    65,    66,    66,
      67,    67,    68,    68,    68,    68,    68,    68,    68,    69,
      69,    70,    70,    70,    71,    71,    71,    72,    72,    72,
      72,    72,    72,    73,    73,    74,    74,    74,    75,    76,
      77,    77,    78,    79,    79,    80,    81,    81,    82,    82,
      83,    83,    83,    83,    83,    83,    83,    83,    83,    83,
      83,    83,    83,    84,    84,    85,    85,    86,    86
};

/* YYR2[YYN] -- Number of symbols composing right hand side of rule YYN.  */
static const unsigned char yyr2[] =
{
       0,     2,     3,     0,     0,     2,     3,     2,     7,     2,
       1,     1,     1,     1,     2,     3,     0,     3,     1,     2,
       1,     1,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     2,     1,     3,     6,     1,     1,     1,     2,     1,
       1,     2,     2,     2,     3,     3,     2,     3,     4,     5,
       3,     4,     4,     1,     1,     2,     3,     3,     3,     6,
       1,     2,     4,     1,     2,     7,     0,     2,     3,     5,
       1,     1,     1,     1,     1,     1,     1,     1,     1,     1,
       1,     1,     1,     0,     3,     1,     5,     0,     1
};

/* YYDEFACT[STATE-NAME] -- Default rule to reduce with in state
   STATE-NUM when YYTABLE doesn't specify something else to do.  Zero
   means the default is an error.  */
static const unsigned char yydefact[] =
{
       3,     0,     4,     1,     0,     0,     0,    10,    11,    12,
       0,     5,     0,     2,    13,     0,     9,     0,    87,     7,
      14,     0,     0,     6,    88,     0,    20,    21,    22,    23,
      24,    25,    26,    27,     0,    18,     0,     0,     0,     0,
       0,     0,     0,    53,    54,     0,     0,     0,     0,     0,
       0,     0,     0,    30,    32,    39,    40,    35,     0,    36,
      37,     0,     0,    17,    28,    29,    19,    38,     0,     0,
      41,    42,    46,    43,     0,     0,     0,     0,    85,    55,
       0,     0,     0,    87,    31,     0,    87,     0,     0,    63,
      45,    44,    33,     0,    50,     0,     0,     0,    56,    57,
      58,     0,    47,     0,     0,     0,    64,    48,     0,    51,
      52,     0,     0,     0,     0,    60,    87,     8,    49,     0,
       0,     0,     0,    61,    66,    86,    34,    87,    59,     0,
      62,    81,    70,    71,    72,    73,    74,    75,    76,    77,
      78,    79,    80,    82,     0,    67,     0,    65,     0,    83,
      68,     0,     0,     0,    69,    84
};

/* YYDEFGOTO[NTERM-NUM]. */
static const short yydefgoto[] =
{
      -1,     1,     2,     4,    11,    12,    13,    14,    15,    22,
      34,    35,    66,    52,    53,    54,    55,    56,    57,    58,
      59,    60,    62,   114,   115,    88,    89,   129,   145,   146,
     151,    80,    25
};

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
#define YYPACT_NINF -87
static const short yypact[] =
{
     -87,     5,   -87,   -87,    12,   -38,    11,   -87,   -87,   -87,
     -27,   -87,   -19,    29,   -87,    30,   -87,    -9,    -8,   -87,
     -87,    79,    53,   -87,   -87,     8,   -87,   -87,   -87,   -87,
     -87,   -87,   -87,   -87,    -5,     9,     6,    10,    22,    23,
      48,    49,    95,   -87,   -87,   108,   109,   111,    -2,   113,
     113,    67,    36,   -87,   -87,   -87,   -87,   -87,   113,   -87,
     -87,    68,    83,   -87,   -87,   -87,   -87,   -87,    71,    72,
     -87,   -87,   -87,   -87,    73,   113,     0,   113,    74,   -87,
      75,    76,    78,    -8,   -87,    80,    -8,   120,   -26,   -87,
     -87,   -87,   -87,     1,   -87,    81,    82,   125,   -87,   -87,
     -87,    83,   -87,   129,    84,    86,   -87,   -87,    87,   -87,
     -87,    85,   -22,    88,    -3,   -87,    -8,   -87,   -87,   130,
      89,   136,    92,   -87,   -87,   -87,   -87,    -8,   -87,    63,
     -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,   -87,
     -87,   -87,   -87,   -87,    93,   -87,     2,   -87,    94,   -87,
     -87,   -29,    96,   141,   -87,   -87
};

/* YYPGOTO[NTERM-NUM].  */
static const short yypgoto[] =
{
     -87,   -87,   -87,   -87,   -87,   -87,   -87,   133,   -87,   -87,
     -87,   -87,   -87,   -87,    97,   -87,   -87,   -87,   -87,   -87,
     -87,   -87,   -87,   -87,    33,    47,   -86,   -87,   -87,   -87,
     -87,   -42,   -74
};

/* YYTABLE[YYPACT[STATE-NUM]].  What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule which
   number is the opposite.  If zero, do what YYDEFACT says.
   If YYTABLE_NINF, syntax error.  */
#define YYTABLE_NINF -17
static const short yytable[] =
{
     113,    78,   106,    78,    78,     3,   148,    81,    82,   101,
      87,    16,   103,     5,    87,    17,    85,     6,     7,     8,
       9,   -16,   152,    18,   153,   105,   106,    64,    65,   120,
      19,    68,    69,    93,    95,    96,   -15,    36,   -16,    21,
      23,    24,   124,    61,    63,   -15,    10,    79,   122,    94,
     107,   108,   149,   130,    36,    67,    37,    38,    39,    40,
      41,    42,    43,    44,    45,    46,    47,    48,    49,    50,
      51,    70,    71,    37,    38,    39,    40,    41,    42,    43,
      44,    45,    46,    47,    48,    49,    50,    51,   131,    26,
      27,    28,    29,    30,    31,    32,    33,    72,    73,    74,
     132,   133,   134,   135,   136,   137,   138,   139,   140,   141,
     142,   143,    75,    76,   144,    77,    78,    83,    86,    87,
      90,    91,    92,   104,    98,    99,    97,   100,   111,   102,
     109,   110,   113,   125,   116,   117,   118,   119,   126,   127,
     121,   128,   147,   150,   155,   154,    20,   123,   112,    84
};

static const unsigned char yycheck[] =
{
       3,     3,    88,     3,     3,     0,     4,    49,    50,    83,
      36,    49,    86,     1,    36,     4,    58,     5,     6,     7,
       8,     9,    51,    50,    53,    51,   112,    18,    19,    51,
      49,    21,    22,    75,    76,    77,     0,     1,     9,     9,
      49,    49,   116,    35,    49,     9,    34,    49,    51,    49,
      49,    93,    50,   127,     1,    49,    20,    21,    22,    23,
      24,    25,    26,    27,    28,    29,    30,    31,    32,    33,
      34,    49,    49,    20,    21,    22,    23,    24,    25,    26,
      27,    28,    29,    30,    31,    32,    33,    34,    25,    10,
      11,    12,    13,    14,    15,    16,    17,    49,    49,     4,
      37,    38,    39,    40,    41,    42,    43,    44,    45,    46,
      47,    48,     4,     4,    51,     4,     3,    50,    50,    36,
      49,    49,    49,     3,    49,    49,    52,    49,     3,    49,
      49,    49,     3,     3,    50,    49,    49,    52,    49,     3,
      52,    49,    49,    49,     3,    49,    13,   114,   101,    52
};

/* YYSTOS[STATE-NUM] -- The (internal number of the) accessing
   symbol of state STATE-NUM.  */
static const unsigned char yystos[] =
{
       0,    55,    56,     0,    57,     1,     5,     6,     7,     8,
      34,    58,    59,    60,    61,    62,    49,     4,    50,    49,
      61,     9,    63,    49,    49,    86,    10,    11,    12,    13,
      14,    15,    16,    17,    64,    65,     1,    20,    21,    22,
      23,    24,    25,    26,    27,    28,    29,    30,    31,    32,
      33,    34,    67,    68,    69,    70,    71,    72,    73,    74,
      75,    35,    76,    49,    18,    19,    66,    49,    21,    22,
      49,    49,    49,    49,     4,     4,     4,     4,     3,    49,
      85,    85,    85,    50,    68,    85,    50,    36,    79,    80,
      49,    49,    49,    85,    49,    85,    85,    52,    49,    49,
      49,    86,    49,    86,     3,    51,    80,    49,    85,    49,
      49,     3,    79,     3,    77,    78,    50,    49,    49,    52,
      51,    52,    51,    78,    86,     3,    49,     3,    49,    81,
      86,    25,    37,    38,    39,    40,    41,    42,    43,    44,
      45,    46,    47,    48,    51,    82,    83,    49,     4,    50,
      49,    84,    51,    53,    49,     3
};

#if ! defined (YYSIZE_T) && defined (__SIZE_TYPE__)
# define YYSIZE_T __SIZE_TYPE__
#endif
#if ! defined (YYSIZE_T) && defined (size_t)
# define YYSIZE_T size_t
#endif
#if ! defined (YYSIZE_T)
# if defined (__STDC__) || defined (__cplusplus)
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# endif
#endif
#if ! defined (YYSIZE_T)
# define YYSIZE_T unsigned int
#endif

#define yyerrok		(yyerrstatus = 0)
#define yyclearin	(yychar = YYEMPTY)
#define YYEMPTY		(-2)
#define YYEOF		0

#define YYACCEPT	goto yyacceptlab
#define YYABORT		goto yyabortlab
#define YYERROR		goto yyerrlab1

/* Like YYERROR except do call yyerror.  This remains here temporarily
   to ease the transition to the new meaning of YYERROR, for GCC.
   Once GCC version 2 has supplanted version 1, this can go.  */

#define YYFAIL		goto yyerrlab

#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)					\
do								\
  if (yychar == YYEMPTY && yylen == 1)				\
    {								\
      yychar = (Token);						\
      yylval = (Value);						\
      yytoken = YYTRANSLATE (yychar);				\
      YYPOPSTACK;						\
      goto yybackup;						\
    }								\
  else								\
    { 								\
      yyerror ("syntax error: cannot back up");\
      YYERROR;							\
    }								\
while (0)

#define YYTERROR	1
#define YYERRCODE	256

/* YYLLOC_DEFAULT -- Compute the default location (before the actions
   are run).  */

#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)         \
  Current.first_line   = Rhs[1].first_line;      \
  Current.first_column = Rhs[1].first_column;    \
  Current.last_line    = Rhs[N].last_line;       \
  Current.last_column  = Rhs[N].last_column;
#endif

/* YYLEX -- calling `yylex' with the right arguments.  */

#ifdef YYLEX_PARAM
# define YYLEX yylex (YYLEX_PARAM)
#else
# define YYLEX yylex ()
#endif

/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)			\
do {						\
  if (yydebug)					\
    YYFPRINTF Args;				\
} while (0)

# define YYDSYMPRINT(Args)			\
do {						\
  if (yydebug)					\
    yysymprint Args;				\
} while (0)

# define YYDSYMPRINTF(Title, Token, Value, Location)		\
do {								\
  if (yydebug)							\
    {								\
      YYFPRINTF (stderr, "%s ", Title);				\
      yysymprint (stderr, 					\
                  Token, Value);	\
      YYFPRINTF (stderr, "\n");					\
    }								\
} while (0)

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (cinluded).                                                   |
`------------------------------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yy_stack_print (short *bottom, short *top)
#else
static void
yy_stack_print (bottom, top)
    short *bottom;
    short *top;
#endif
{
  YYFPRINTF (stderr, "Stack now");
  for (/* Nothing. */; bottom <= top; ++bottom)
    YYFPRINTF (stderr, " %d", *bottom);
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)				\
do {								\
  if (yydebug)							\
    yy_stack_print ((Bottom), (Top));				\
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yy_reduce_print (int yyrule)
#else
static void
yy_reduce_print (yyrule)
    int yyrule;
#endif
{
  int yyi;
  unsigned int yylineno = yyrline[yyrule];
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %u), ",
             yyrule - 1, yylineno);
  /* Print the symbols being reduced, and their result.  */
  for (yyi = yyprhs[yyrule]; 0 <= yyrhs[yyi]; yyi++)
    YYFPRINTF (stderr, "%s ", yytname [yyrhs[yyi]]);
  YYFPRINTF (stderr, "-> %s\n", yytname [yyr1[yyrule]]);
}

# define YY_REDUCE_PRINT(Rule)		\
do {					\
  if (yydebug)				\
    yy_reduce_print (Rule);		\
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args)
# define YYDSYMPRINT(Args)
# define YYDSYMPRINTF(Title, Token, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef	YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   SIZE_MAX < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#if YYMAXDEPTH == 0
# undef YYMAXDEPTH
#endif

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif



#if YYERROR_VERBOSE

# ifndef yystrlen
#  if defined (__GLIBC__) && defined (_STRING_H)
#   define yystrlen strlen
#  else
/* Return the length of YYSTR.  */
static YYSIZE_T
#   if defined (__STDC__) || defined (__cplusplus)
yystrlen (const char *yystr)
#   else
yystrlen (yystr)
     const char *yystr;
#   endif
{
  register const char *yys = yystr;

  while (*yys++ != '\0')
    continue;

  return yys - yystr - 1;
}
#  endif
# endif

# ifndef yystpcpy
#  if defined (__GLIBC__) && defined (_STRING_H) && defined (_GNU_SOURCE)
#   define yystpcpy stpcpy
#  else
/* Copy YYSRC to YYDEST, returning the address of the terminating '\0' in
   YYDEST.  */
static char *
#   if defined (__STDC__) || defined (__cplusplus)
yystpcpy (char *yydest, const char *yysrc)
#   else
yystpcpy (yydest, yysrc)
     char *yydest;
     const char *yysrc;
#   endif
{
  register char *yyd = yydest;
  register const char *yys = yysrc;

  while ((*yyd++ = *yys++) != '\0')
    continue;

  return yyd - 1;
}
#  endif
# endif

#endif /* !YYERROR_VERBOSE */



#if YYDEBUG
/*--------------------------------.
| Print this symbol on YYOUTPUT.  |
`--------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yysymprint (FILE *yyoutput, int yytype, YYSTYPE *yyvaluep)
#else
static void
yysymprint (yyoutput, yytype, yyvaluep)
    FILE *yyoutput;
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  /* Pacify ``unused variable'' warnings.  */
  (void) yyvaluep;

  if (yytype < YYNTOKENS)
    {
      YYFPRINTF (yyoutput, "token %s (", yytname[yytype]);
# ifdef YYPRINT
      YYPRINT (yyoutput, yytoknum[yytype], *yyvaluep);
# endif
    }
  else
    YYFPRINTF (yyoutput, "nterm %s (", yytname[yytype]);

  switch (yytype)
    {
      default:
        break;
    }
  YYFPRINTF (yyoutput, ")");
}

#endif /* ! YYDEBUG */
/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

#if defined (__STDC__) || defined (__cplusplus)
static void
yydestruct (int yytype, YYSTYPE *yyvaluep)
#else
static void
yydestruct (yytype, yyvaluep)
    int yytype;
    YYSTYPE *yyvaluep;
#endif
{
  /* Pacify ``unused variable'' warnings.  */
  (void) yyvaluep;

  switch (yytype)
    {

      default:
        break;
    }
}


/* Prevent warnings from -Wmissing-prototypes.  */

#ifdef YYPARSE_PARAM
# if defined (__STDC__) || defined (__cplusplus)
int yyparse (void *YYPARSE_PARAM);
# else
int yyparse ();
# endif
#else /* ! YYPARSE_PARAM */
#if defined (__STDC__) || defined (__cplusplus)
int yyparse (void);
#else
int yyparse ();
#endif
#endif /* ! YYPARSE_PARAM */



/* The lookahead symbol.  */
int yychar;

/* The semantic value of the lookahead symbol.  */
YYSTYPE yylval;

/* Number of syntax errors so far.  */
int yynerrs;



/*----------.
| yyparse.  |
`----------*/

#ifdef YYPARSE_PARAM
# if defined (__STDC__) || defined (__cplusplus)
int yyparse (void *YYPARSE_PARAM)
# else
int yyparse (YYPARSE_PARAM)
  void *YYPARSE_PARAM;
# endif
#else /* ! YYPARSE_PARAM */
#if defined (__STDC__) || defined (__cplusplus)
int
yyparse (void)
#else
int
yyparse ()

#endif
#endif
{
  
  register int yystate;
  register int yyn;
  int yyresult;
  /* Number of tokens to shift before error messages enabled.  */
  int yyerrstatus;
  /* Lookahead token as an internal (translated) token number.  */
  int yytoken = 0;

  /* Three stacks and their tools:
     `yyss': related to states,
     `yyvs': related to semantic values,
     `yyls': related to locations.

     Refer to the stacks thru separate pointers, to allow yyoverflow
     to reallocate them elsewhere.  */

  /* The state stack.  */
  short	yyssa[YYINITDEPTH];
  short *yyss = yyssa;
  register short *yyssp;

  /* The semantic value stack.  */
  YYSTYPE yyvsa[YYINITDEPTH];
  YYSTYPE *yyvs = yyvsa;
  register YYSTYPE *yyvsp;



#define YYPOPSTACK   (yyvsp--, yyssp--)

  YYSIZE_T yystacksize = YYINITDEPTH;

  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;


  /* When reducing, the number of symbols on the RHS of the reduced
     rule.  */
  int yylen;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yystate = 0;
  yyerrstatus = 0;
  yynerrs = 0;
  yychar = YYEMPTY;		/* Cause a token to be read.  */

  /* Initialize stack pointers.
     Waste one element of value and location stack
     so that they stay on the same level as the state stack.
     The wasted elements are never initialized.  */

  yyssp = yyss;
  yyvsp = yyvs;

  goto yysetstate;

/*------------------------------------------------------------.
| yynewstate -- Push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
 yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed. so pushing a state here evens the stacks.
     */
  yyssp++;

 yysetstate:
  *yyssp = yystate;

  if (yyss + yystacksize - 1 <= yyssp)
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYSIZE_T yysize = yyssp - yyss + 1;

#ifdef yyoverflow
      {
	/* Give user a chance to reallocate the stack. Use copies of
	   these so that the &'s don't force the real ones into
	   memory.  */
	YYSTYPE *yyvs1 = yyvs;
	short *yyss1 = yyss;


	/* Each stack pointer address is followed by the size of the
	   data in use in that stack, in bytes.  This used to be a
	   conditional around just the two extra args, but that might
	   be undefined if yyoverflow is a macro.  */
	yyoverflow ("parser stack overflow",
		    &yyss1, yysize * sizeof (*yyssp),
		    &yyvs1, yysize * sizeof (*yyvsp),

		    &yystacksize);

	yyss = yyss1;
	yyvs = yyvs1;
      }
#else /* no yyoverflow */
# ifndef YYSTACK_RELOCATE
      goto yyoverflowlab;
# else
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
	goto yyoverflowlab;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
	yystacksize = YYMAXDEPTH;

      {
	short *yyss1 = yyss;
	union yyalloc *yyptr =
	  (union yyalloc *) YYSTACK_ALLOC (YYSTACK_BYTES (yystacksize));
	if (! yyptr)
	  goto yyoverflowlab;
	YYSTACK_RELOCATE (yyss);
	YYSTACK_RELOCATE (yyvs);

#  undef YYSTACK_RELOCATE
	if (yyss1 != yyssa)
	  YYSTACK_FREE (yyss1);
      }
# endif
#endif /* no yyoverflow */

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;


      YYDPRINTF ((stderr, "Stack size increased to %lu\n",
		  (unsigned long int) yystacksize));

      if (yyss + yystacksize - 1 <= yyssp)
	YYABORT;
    }

  YYDPRINTF ((stderr, "Entering state %d\n", yystate));

  goto yybackup;

/*-----------.
| yybackup.  |
`-----------*/
yybackup:

/* Do appropriate processing given the current state.  */
/* Read a lookahead token if we need one and don't already have one.  */
/* yyresume: */

  /* First try to decide what to do without reference to lookahead token.  */

  yyn = yypact[yystate];
  if (yyn == YYPACT_NINF)
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either YYEMPTY or YYEOF or a valid lookahead symbol.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token: "));
      yychar = YYLEX;
    }

  if (yychar <= YYEOF)
    {
      yychar = yytoken = YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YYDSYMPRINTF ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yyn == 0 || yyn == YYTABLE_NINF)
	goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  /* Shift the lookahead token.  */
  YYDPRINTF ((stderr, "Shifting token %s, ", yytname[yytoken]));

  /* Discard the token being shifted unless it is eof.  */
  if (yychar != YYEOF)
    yychar = YYEMPTY;

  *++yyvsp = yylval;


  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  yystate = yyn;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- Do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     `$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
        case 3:
#line 107 "toc_parse.y"
    {
		cd = cd_init();
		cdtext = cd_get_cdtext(cd);
	}
    break;

  case 6:
#line 119 "toc_parse.y"
    { cd_set_catalog(cd, yyvsp[-1].sval); }
    break;

  case 7:
#line 120 "toc_parse.y"
    { cd_set_mode(cd, yyvsp[-1].ival); }
    break;

  case 15:
#line 137 "toc_parse.y"
    {
		while (2 > track_get_nindex(track))
			track_add_index(track, 0);
	}
    break;

  case 16:
#line 144 "toc_parse.y"
    {
		track = cd_add_track(cd);
		cdtext = track_get_cdtext(track);
		/* add 0 index */
		track_add_index(track, 0);
	}
    break;

  case 17:
#line 153 "toc_parse.y"
    { track_set_mode(track, yyvsp[-1].ival); }
    break;

  case 19:
#line 158 "toc_parse.y"
    { track_set_sub_mode(track, yyvsp[0].ival); }
    break;

  case 33:
#line 184 "toc_parse.y"
    { track_set_isrc(track, yyvsp[-1].sval); }
    break;

  case 39:
#line 193 "toc_parse.y"
    { track_set_flag(track, yyvsp[0].ival); }
    break;

  case 40:
#line 194 "toc_parse.y"
    { track_clear_flag(track, yyvsp[0].ival); }
    break;

  case 44:
#line 204 "toc_parse.y"
    { yyval.ival = yyvsp[-1].ival; }
    break;

  case 45:
#line 205 "toc_parse.y"
    { yyval.ival = yyvsp[-1].ival; }
    break;

  case 47:
#line 210 "toc_parse.y"
    {
		if (NULL == track_get_filename(track))
			track_set_zero_pre(track, yyvsp[-1].ival);
		else
			track_set_zero_post(track, yyvsp[-1].ival);
	}
    break;

  case 48:
#line 216 "toc_parse.y"
    {
		track_set_filename(track, yyvsp[-2].sval);
		track_set_start(track, yyvsp[-1].ival);
	}
    break;

  case 49:
#line 220 "toc_parse.y"
    {
		track_set_filename(track, yyvsp[-3].sval);
		track_set_start(track, yyvsp[-2].ival);
		track_set_length(track, yyvsp[-1].ival);
	}
    break;

  case 50:
#line 225 "toc_parse.y"
    {
		track_set_filename(track, yyvsp[-1].sval);
	}
    break;

  case 51:
#line 228 "toc_parse.y"
    {
		track_set_filename(track, yyvsp[-2].sval);
		track_set_start(track, yyvsp[-1].ival);
	}
    break;

  case 52:
#line 232 "toc_parse.y"
    {
		track_set_filename(track, yyvsp[-2].sval);
		track_set_start(track, yyvsp[-1].ival);
	}
    break;

  case 56:
#line 245 "toc_parse.y"
    {
		track_add_index(track, yyvsp[-1].ival);
	}
    break;

  case 57:
#line 248 "toc_parse.y"
    {
		track_set_zero_pre(track, yyvsp[-1].ival);
		track_add_index(track, yyvsp[-1].ival);
	}
    break;

  case 58:
#line 255 "toc_parse.y"
    { track_add_index(track, yyvsp[-1].ival); }
    break;

  case 62:
#line 268 "toc_parse.y"
    { /* not implemented */ }
    break;

  case 68:
#line 286 "toc_parse.y"
    {
		cdtext_set (yyvsp[-2].ival, yyvsp[-1].sval, cdtext);
	}
    break;

  case 69:
#line 289 "toc_parse.y"
    {
		yyerror("binary CD-TEXT data not supported\n");
	}
    break;

  case 86:
#line 317 "toc_parse.y"
    { yyval.ival = time_msf_to_frame(yyvsp[-4].ival, yyvsp[-2].ival, yyvsp[0].ival); }
    break;


    }

/* Line 991 of yacc.c.  */
#line 1399 "toc_parse.c"

  yyvsp -= yylen;
  yyssp -= yylen;


  YY_STACK_PRINT (yyss, yyssp);

  *++yyvsp = yyval;


  /* Now `shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */

  yyn = yyr1[yyn];

  yystate = yypgoto[yyn - YYNTOKENS] + *yyssp;
  if (0 <= yystate && yystate <= YYLAST && yycheck[yystate] == *yyssp)
    yystate = yytable[yystate];
  else
    yystate = yydefgoto[yyn - YYNTOKENS];

  goto yynewstate;


/*------------------------------------.
| yyerrlab -- here on detecting error |
`------------------------------------*/
yyerrlab:
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
#if YYERROR_VERBOSE
      yyn = yypact[yystate];

      if (YYPACT_NINF < yyn && yyn < YYLAST)
	{
	  YYSIZE_T yysize = 0;
	  int yytype = YYTRANSLATE (yychar);
	  char *yymsg;
	  int yyx, yycount;

	  yycount = 0;
	  /* Start YYX at -YYN if negative to avoid negative indexes in
	     YYCHECK.  */
	  for (yyx = yyn < 0 ? -yyn : 0;
	       yyx < (int) (sizeof (yytname) / sizeof (char *)); yyx++)
	    if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
	      yysize += yystrlen (yytname[yyx]) + 15, yycount++;
	  yysize += yystrlen ("syntax error, unexpected ") + 1;
	  yysize += yystrlen (yytname[yytype]);
	  yymsg = (char *) YYSTACK_ALLOC (yysize);
	  if (yymsg != 0)
	    {
	      char *yyp = yystpcpy (yymsg, "syntax error, unexpected ");
	      yyp = yystpcpy (yyp, yytname[yytype]);

	      if (yycount < 5)
		{
		  yycount = 0;
		  for (yyx = yyn < 0 ? -yyn : 0;
		       yyx < (int) (sizeof (yytname) / sizeof (char *));
		       yyx++)
		    if (yycheck[yyx + yyn] == yyx && yyx != YYTERROR)
		      {
			const char *yyq = ! yycount ? ", expecting " : " or ";
			yyp = yystpcpy (yyp, yyq);
			yyp = yystpcpy (yyp, yytname[yyx]);
			yycount++;
		      }
		}
	      yyerror (yymsg);
	      YYSTACK_FREE (yymsg);
	    }
	  else
	    yyerror ("syntax error; also virtual memory exhausted");
	}
      else
#endif /* YYERROR_VERBOSE */
	yyerror ("syntax error");
    }



  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
	 error, discard it.  */

      /* Return failure if at end of input.  */
      if (yychar == YYEOF)
        {
	  /* Pop the error token.  */
          YYPOPSTACK;
	  /* Pop the rest of the stack.  */
	  while (yyss < yyssp)
	    {
	      YYDSYMPRINTF ("Error: popping", yystos[*yyssp], yyvsp, yylsp);
	      yydestruct (yystos[*yyssp], yyvsp);
	      YYPOPSTACK;
	    }
	  YYABORT;
        }

      YYDSYMPRINTF ("Error: discarding", yytoken, &yylval, &yylloc);
      yydestruct (yytoken, &yylval);
      yychar = YYEMPTY;

    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab2;


/*----------------------------------------------------.
| yyerrlab1 -- error raised explicitly by an action.  |
`----------------------------------------------------*/
yyerrlab1:

  /* Suppress GCC warning that yyerrlab1 is unused when no action
     invokes YYERROR.  MacOS 10.2.3's buggy "smart preprocessor"
     insists on the trailing semicolon.  */
#if defined (__GNUC_MINOR__) && 2093 <= (__GNUC__ * 1000 + __GNUC_MINOR__)
  __attribute__ ((__unused__));
#endif


  goto yyerrlab2;


/*---------------------------------------------------------------.
| yyerrlab2 -- pop states until the error token can be shifted.  |
`---------------------------------------------------------------*/
yyerrlab2:
  yyerrstatus = 3;	/* Each real token shifted decrements this.  */

  for (;;)
    {
      yyn = yypact[yystate];
      if (yyn != YYPACT_NINF)
	{
	  yyn += YYTERROR;
	  if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYTERROR)
	    {
	      yyn = yytable[yyn];
	      if (0 < yyn)
		break;
	    }
	}

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
	YYABORT;

      YYDSYMPRINTF ("Error: popping", yystos[*yyssp], yyvsp, yylsp);
      yydestruct (yystos[yystate], yyvsp);
      yyvsp--;
      yystate = *--yyssp;

      YY_STACK_PRINT (yyss, yyssp);
    }

  if (yyn == YYFINAL)
    YYACCEPT;

  YYDPRINTF ((stderr, "Shifting error token, "));

  *++yyvsp = yylval;


  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturn;

/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturn;

#ifndef yyoverflow
/*----------------------------------------------.
| yyoverflowlab -- parser overflow comes here.  |
`----------------------------------------------*/
yyoverflowlab:
  yyerror ("parser stack overflow");
  yyresult = 2;
  /* Fall through.  */
#endif

yyreturn:
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif
  return yyresult;
}


#line 102 "toc_parse.y"


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

