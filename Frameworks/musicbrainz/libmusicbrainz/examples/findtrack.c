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

     $Id: findtrack.c 671 2004-01-14 08:52:28Z robert $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include "musicbrainz/mb_c.h"

int main(int argc, char *argv[])
{
    musicbrainz_t o;
    char          error[256], data[1024], temp[256], *args[4];
    char          *rdfdata;
    int           ret, numTracks, i;

    if (argc < 2)
    {
        printf("Usage: findtrack <track name>\n");
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
        mb_SetDepth(o, 4);

    // Set up the args for the find artist query
    args[0] = argv[1];
    args[1] = (argc == 4) ? argv[3] : ""; 
    args[2] = argv[2];
    args[3] = NULL;

    // Execute the MB_FindTrackByName query
    ret = mb_QueryWithArgs(o, MBQ_FindTrackByName, args);
    if (!ret)
    {
        mb_GetQueryError(o, error, 256);
        printf("Query failed: %s\n", error);
        mb_Delete(o);
        return 0;
    }

    rdfdata = malloc(mb_GetResultRDFLen(o));
    mb_GetResultRDF(o, rdfdata, mb_GetResultRDFLen(o));
    
    // Check to see how many items were returned from the server
    numTracks = mb_GetResultInt(o, MBE_GetNumTracks);
    if (numTracks < 1)
    {
        printf("No tracks found.\n");
        mb_Delete(o);
        return 0;
    }  
    printf("Found %d tracks.\n\n", numTracks);

    for(i = 1; i <= numTracks; i++)
    {
        // Start at the top of the query and work our way down
        mb_Select(o, MBS_Rewind);  

        // Select the ith artist
        mb_Select1(o, MBS_SelectTrack, i);  

        // Extract the artist name from the ith track
        mb_GetResultData(o, MBE_TrackGetTrackName, data, 256);
        printf("     Track: '%s'\n", data);

        // Extract the artist name from the ith track
        mb_GetResultData(o, MBE_TrackGetArtistName, data, 256);
        printf("    Artist: '%s'\n", data);

        // Extract the artist id from the ith track
        mb_GetResultData(o, MBE_TrackGetArtistId, data, 256);
        mb_GetIDFromURL(o, data, temp, 256);
        printf("  ArtistId: '%s'\n", temp);

        printf("\n");
    }

#ifdef WIN32
    mb_WSAStop(o);
#endif

    // and clean up the musicbrainz object
    mb_Delete(o);

    return 0;
}
