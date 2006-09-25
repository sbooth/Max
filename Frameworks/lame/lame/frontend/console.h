/*
 * frontend/console.h
 *
 * This 
 *
 *
 */
 
#ifndef LAME_CONSOLE_H
#define LAME_CONSOLE_H

#if defined(_WIN32)  &&  !defined(__CYGWIN__)
# include <windows.h>
#endif

typedef struct {
    unsigned long  ClassID;
    unsigned long  ClassProt;
    FILE*          Console_fp;  /* filepointer to stream reporting information */
    FILE*          Error_fp;    /* filepointer to stream fatal error reporting information */
    FILE*          Report_fp;   /* filepointer to stream reports (normally a text file or /dev/null) */
    char*          Console_buff;
#if defined(_WIN32)  &&  !defined(__CYGWIN__) 
    HANDLE         Console_Handle;
#endif
    int            disp_width;
    int            disp_height;
    char           str_up         [10];
    char           str_clreoln    [10];
    char           str_emph       [10];
    char           str_norm       [10];
} Console_IO_t;

#endif /* LAME_CONSOLE_H */

/* end of console.h */

