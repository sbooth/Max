/* config.h.  Generated automatically by configure.  */
/* config.h.in.  Generated automatically from configure.in by autoheader.  */

/* Define if your processor stores words with the most significant
   byte first (like Motorola and SPARC, unlike Intel and VAX).  */
/* #undef WORDS_BIGENDIAN */
#ifndef _CONFIG_WIN32_H_
#define _CONFIG_WIN32_H_

#define PACKAGE "musicbrainz"
#define VERSION "2.1.4"

/* The number of bytes in a long.  */
#define SIZEOF_LONG 4

#define usleep(x) ::Sleep(x/1000)
#define strcasecmp(a,b) stricmp(a,b)
#define strncasecmp(a,b,c) strnicmp(a,b,c)
typedef int socklen_t;

#endif
