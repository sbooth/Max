#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#ifdef STDC_HEADERS
# include <stdlib.h>
# include <string.h>
#else
# ifndef HAVE_STRCHR
#  define strchr index
#  define strrchr rindex
# endif
char *strchr (), *strrchr ();
# ifndef HAVE_MEMCPY
#  define memcpy(d, s, n) bcopy ((s), (d), (n))
#  define memmove(d, s, n) bcopy ((s), (d), (n))
# endif
#endif

#include "console.h"

#if defined(HAVE_TERMCAP)
#include <curses.h> 
#include <term.h>
#if defined(HAVE_TERMCAP_H)
# include <termcap.h>
#elif defined(HAVE_NCURSES_TERMCAP_H)
# include <ncurses/termcap.h>
#endif
#endif

#ifdef WITH_DMALLOC
#include <dmalloc.h>
#endif

#define CLASS_ID           0x434F4E53
#define REPORT_BUFF_SIZE   1024

/* 
 * Taken from Termcap_Manual.html:
 *
 * With the Unix version of termcap, you must allocate space for the description yourself and pass
 * the address of the space as the argument buffer. There is no way you can tell how much space is
 * needed, so the convention is to allocate a buffer 2048 characters long and assume that is
 * enough.  (Formerly the convention was to allocate 1024 characters and assume that was enough.
 * But one day, for one kind of terminal, that was not enough.)
 */

Console_IO_t*  open_console ( int debug )
{
    Console_IO_t* const  mfp = calloc ( 1, sizeof (*mfp) );
#ifdef TERMCAP_AVAILABLE
    const char*          term_name;
    char                 term_buff [2048];
    char*                tp;
    char                 tc [10];
    int                  val;
#endif

    /* setup basics of brhist I/O channels */
    mfp -> disp_width   = 80;
    mfp -> disp_height  = 25;
    mfp -> Console_fp   = stderr;
    mfp -> Error_fp     = stderr;
    mfp -> Report_fp    = debug  ?  fopen ( "/tmp/lame_reports", "a" )  :  NULL;

    mfp -> Console_buff = calloc ( 1, REPORT_BUFF_SIZE );
    setvbuf ( mfp -> Console_fp, mfp -> Console_buff, _IOFBF, REPORT_BUFF_SIZE );
/*  setvbuf ( mfp -> Error_fp  , NULL                   , _IONBF, 0                                ); */

#if defined(_WIN32)  &&  !defined(__CYGWIN__) 
    mfp -> Console_Handle = GetStdHandle (STD_ERROR_HANDLE);
#endif

    strcpy ( mfp -> str_up, "\033[A" );
    
#ifdef TERMCAP_AVAILABLE
    /* try to catch additional information about special console sequences */
    
    if ((term_name = getenv("TERM")) == NULL) {
	fprintf ( mfp -> Error_fp, "LAME: Can't get \"TERM\" environment string.\n" );
	return -1;
    }
    if ( tgetent (term_buff, term_name) != 1 ) {
	fprintf ( mfp -> Error_fp, "LAME: Can't find termcap entry for terminal \"%s\"\n", term_name );
	return -1;
    }
    
    val = tgetnum ("co");
    if ( val >= 40  &&  val <= 512 )
        mfp -> disp_width   = val;
    val = tgetnum ("li");
    if ( val >= 16  &&  val <= 256 )
        mfp -> disp_height  = val;
        
    *(tp = tc) = '\0';
    tp = tgetstr ("up", &tp);
    if (tp != NULL)
        strcpy ( mfp -> str_up, tp );

    *(tp = tc) = '\0';
    tp = tgetstr ("ce", &tp);
    if (tp != NULL)
        strcpy ( mfp -> str_clreoln, tp );

    *(tp = tc) = '\0';
    tp = tgetstr ("md", &tp);
    if (tp != NULL)
        strcpy ( mfp -> str_emph, tp );

    *(tp = tc) = '\0';
    tp = tgetstr ("me", &tp);
    if (tp != NULL)
        strcpy ( mfp -> str_norm, tp );
        
#endif /* TERMCAP_AVAILABLE */

    return mfp;
}

/* printf for console */

int  Console_printf ( Console_IO_t* const mfp, const char* const format, ... )
{
    va_list  args;
    int      ret;

    va_start ( args, format );
    ret = vfprintf ( mfp -> Console_fp, s, args );
    va_end ( args );
    
    return ret;
}

/* printf for errors */

int  Error_printf ( Console_IO_t* const mfp, const char* const format, ... )
{
    va_list  args;
    int      ret;

    va_start ( args, format );
    ret = vfprintf ( mfp -> Error_fp, s, args );
    va_end ( args );
    
    flush ( mfp -> Error_fp );
    return ret;
}

/* printf for additional reporting information */

int  Report_printf ( Console_IO_t* const mfp, const char* const format, ... )
{
    va_list  args;
    int      ret;

    if ( mfp -> Report_fp != NULL ) {
        va_start ( args, format );
        ret = vfprintf ( mfp -> Report_fp, s, args );
        va_end ( args );
        
        return ret;
    }
    
    return 0;
}


int  close_console ( Console_IO_t* const mfp )
{
    if ( mfp == NULL  ||  mfp -> ClassID != CLASS_ID  ||  mfp -> Console_buff == NULL )
        return -1;
	
    fflush  ( mfp -> Console_fp );
    setvbuf ( mfp -> Console_fp, NULL, _IONBF, (size_t)0 );
    
    memset ( mfp -> Console_buff, 0x55, REPORT_BUFF_SIZE );
    free   ( mfp -> Console_buff );
    
    memset ( mfp, 0x55, sizeof (*mfp) );
    free   ( mfp );
    
    return 0;
}

/* end of console.c */

