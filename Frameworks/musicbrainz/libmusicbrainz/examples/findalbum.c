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

     $Id: findalbum.c 671 2004-01-14 08:52:28Z robert $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include "musicbrainz/mb_c.h"

int main(int argc, char *argv[])
{
    musicbrainz_t o;
    char          error[256], data[256], temp[256], *args[2];
    int           ret, numAlbums, i;

    if (argc < 2)
    {
        printf("Usage: findalbum <album name>\n");
        exit(0);
    }

    // Create the musicbrainz object, which will be needed for subsequent calls
    o = mb_New();

#ifdef WIN32
    mb_WSAInit(o);
#endif

    // Tell the client library to return data in ISO8859-1 and not UTF-8
    mb_UseUTF8(o, 0);

    // Tell the server to return max 10 items.
    mb_SetMaxItems(o, 10);

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

    // Set up the args for the find artist query
    args[0] = argv[1];
    args[1] = NULL;

    // Execute the MB_FindAlbumByName query
    ret = mb_QueryWithArgs(o, MBQ_FindAlbumByName, args);
    if (!ret)
    {
        mb_GetQueryError(o, error, 256);
        printf("Query failed: %s\n", error);
        mb_Delete(o);
        return 0;
    }

    // Check to see how many items were returned from the server
    numAlbums = mb_GetResultInt(o, MBE_GetNumAlbums);
    if (numAlbums < 1)
    {
        printf("No albums found.\n");
        mb_Delete(o);
        return 0;
    }  
    printf("Found %d albums.\n\n", numAlbums);

    for(i = 1; i <= numAlbums; i++)
    {
        // Start at the top of the query and work our way down
        mb_Select(o, MBS_Rewind);  

        // Select the ith album
        mb_Select1(o, MBS_SelectAlbum, i);  

        // Extract the album name
        mb_GetResultData(o, MBE_AlbumGetAlbumName, data, 256);
        printf("    Album: '%s'\n", data);

        // Extract the album id from the ith track
        mb_GetResultData(o, MBE_AlbumGetAlbumId, data, 256);
        mb_GetIDFromURL(o, data, temp, 256);
        printf("  AlbumId: '%s'\n", temp);

        // Extract the artist id from the ith track
        mb_GetResultData(o, MBE_AlbumGetAlbumArtistId, data, 256);
        mb_GetIDFromURL(o, data, temp, 256);
        printf(" ArtistId: '%s'\n", temp);

        printf("\n");
    }

#ifdef WIN32
    mb_WSAInit(o);
#endif

    // and clean up the musicbrainz object
    mb_Delete(o);

    return 0;
}
