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

     $Id: gettrm.c 671 2004-01-14 08:52:28Z robert $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include "musicbrainz/mb_c.h"

int main(int argc, char *argv[])
{
    musicbrainz_t o;
    char          error[256], data[256],*args[2], trackURI[256];
    int           ret, trackNum, index, duration;

    if (argc < 2)
    {
        printf("Usage: gettrm <trmid>\n");
        exit(0);
    }

    // Create the musicbrainz object, which will be needed for subsequent calls
    o = mb_New();

#ifdef WIN32
    mb_WSAInit(o);
#endif

    // Tell the client library to return data in ISO8859-1 and not UTF-8
    mb_UseUTF8(o, 0);

    // Set the proper server to use. Defaults to mm.musicbrainz.org:80
    if (getenv("MB_SERVER"))
        mb_SetServer(o, getenv("MB_SERVER"), 80);

    // Check to see if the debug env var has been set 
    if (getenv("MB_DEBUG"))
        mb_SetDebug(o, atoi(getenv("MB_DEBUG")));

    // Set up the args for the trm query
    args[0] = argv[1];
    args[1] = NULL;

    // Execute the MBQ_TrackInfoFromTRMId query
    ret = mb_QueryWithArgs(o, MBQ_TrackInfoFromTRMId, args);
    if (!ret)
    {
        mb_GetQueryError(o, error, 256);
        printf("Query failed: %s\n", error);
        mb_Delete(o);
        return 0;
    }

    for(index = 1;; index++)
    {
        mb_Select(o, MBS_Rewind);

        // Select the first track from the track list 
        if (!mb_Select1(o, MBS_SelectTrack, index))
        {
            if (index == 1)
                printf("That TRM is not in the database\n");

            break;
        }

        mb_GetResultData(o, MBE_TrackGetTrackId, trackURI, 256);

        // Extract the artist name from the track
        if (mb_GetResultData(o, MBE_TrackGetArtistName, data, 256))
           printf("    Artist: '%s'\n", data);

        // Extract the track name
        if (mb_GetResultData(o, MBE_TrackGetTrackName, data, 256))
           printf("     Track: '%s'\n", data);

        // Extract the track duration
        duration = mb_GetResultInt(o, MBE_TrackGetTrackDuration);
        printf("  Duration: %d ms\n", duration);

        mb_Select(o, MBS_SelectTrackAlbum);

        // Extract the track number
        trackNum = mb_GetOrdinalFromList(o, MBE_AlbumGetTrackList, trackURI);
        if (trackNum > 0 && trackNum < 100)
           printf("  TrackNum: %d\n", trackNum);

        // Extract the album name from the track
        if (mb_GetResultData(o, MBE_AlbumGetAlbumName, data, 256))
           printf("     Album: '%s'\n", data);
    }

#ifdef WIN32
    mb_WSAStop(o);
#endif

    // and clean up the musicbrainz object
    mb_Delete(o);

    return 0;
}
