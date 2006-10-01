/* --------------------------------------------------------------------------

   MusicBrainz -- The Internet music metadatabase

   Copyright (C) 2000 Robert Kaye
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

     $Id: cdlookup.c 671 2004-01-14 08:52:28Z robert $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/stat.h>
#endif
#include <string.h>
#include "musicbrainz/mb_c.h"
#include "musicbrainz/browser.h"

int main(int argc, char *argv[])
{
    musicbrainz_t o;
    char          url[1025], *browser = NULL;
    int           argIndex = 1;

    if (argc > 1 && strcmp(argv[1], "--help") == 0)
    {
        printf("Usage: cdlookup [options] [device]\n");
        printf("\nDefault drive is /dev/cdrom\n");
        printf("\nOptions:\n");
        printf(" -k       - use the Konqueror to submit\n");
        printf(" -m       - use the Mozilla to submit\n");
        printf(" -o       - use the Opera to submit\n");
        printf(" -l       - use the lynx to submit\n");
        printf(" -g       - use the galeon to submit\n");
        printf("\nBy default Netscape will be used. You may also set the\n");
        printf("BROWSER environment variable to specify your browser of "
               "choice. Check http://www.tuxedo.org/~esr/BROWSER/index.html "
               "for details.\n");
        exit(0);
    }

    // Create the musicbrainz object, which will be needed for subsequent calls
    o = mb_New();

#ifdef WIN32
    mb_WSAInit(o);
#endif

    // Set the proper server to use. Defaults to mm.musicbrainz.org:80
    if (getenv("MB_SERVER"))
        mb_SetServer(o, getenv("MB_SERVER"), 80);

    // Check to see if the debug env var has been set 
    if (getenv("MB_DEBUG"))
        mb_SetDebug(o, atoi(getenv("MB_DEBUG")));

    // Tell the server to only return 2 levels of data, unless the MB_DEPTH env var is set
    if (getenv("MB_DEPTH"))
        mb_SetDepth(o, atoi(getenv("MB_DEPTH")));
    else
        mb_SetDepth(o, 2);

    // If a device was specified on the command line, then pass on 
    if (argc > 1)
    {
        for(; argIndex < argc; argIndex++)
        {
            if (strcmp(argv[argIndex], "-m") == 0)
            {
                browser = "mozilla";
            }
            else
            if (strcmp(argv[argIndex], "-k") == 0)
            {
                browser = "konqueror";
            }
            else
            if (strcmp(argv[argIndex], "-o") == 0)
            {
                browser = "opera";
                }
            else
            if (strcmp(argv[argIndex], "-l") == 0)
            {
                browser = "lynx";
            }
            else
            if (strcmp(argv[argIndex], "-g") == 0)
            {
                browser = "galeon";
            }
            else
            {
                printf("Using device: %s\n", argv[argIndex]);
                    mb_SetDevice(o, argv[argIndex]);
                break;
            }
        } 
    } 

    // Tell the client library to return data in ISO8859-1 and not UTF-8
    mb_UseUTF8(o, 0);

    // Now get the web submit url
    if (mb_GetWebSubmitURL(o, url, 1024))
    {
        int ret;
        
        printf("URL: %s\n", url);

        browser = browser ? browser : "mozilla";
        ret = LaunchBrowser(url, browser);
        if (ret == 0)
           printf("Could not launch browser. (%s)\n", browser);
    }
    else
        printf("Could read CD-ROM parameters. Is there a CD in the drive?\n");

#ifdef WIN32
    mb_WSAInit(o);
#endif

    // and clean up the musicbrainz object
    mb_Delete(o);

    return 0;
}
