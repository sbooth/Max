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

     $Id: getalbum.c 751 2005-10-27 00:23:32Z robert $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "musicbrainz/mb_c.h"

int main(int argc, char *argv[])
{
    musicbrainz_t o;
    char          error[256], data[256], temp[256], *args[2];
    int           ret, numTracks, trackNum, i, isMultipleArtist = 0, numDates, albumNum;

    if (argc < 2)
    {
        printf("Usage: getalbum <albumid|cdindexid>\n");
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

    // Tell the server to only return 2 levels of data, unless the MB_DEPTH env var is set
    if (getenv("MB_DEPTH"))
        mb_SetDepth(o, atoi(getenv("MB_DEPTH")));
    else
        mb_SetDepth(o, 4);

    // Set up the args for the find album query
    args[0] = argv[1];
    args[1] = NULL;

    if (strlen(argv[1]) != MB_CDINDEX_ID_LEN)
        // Execute the MB_GetAlbumById query
        ret = mb_QueryWithArgs(o, MBQ_GetAlbumById, args);
    else
        // Execute the MBQ_GetCDInfoFromCDIndexId
        ret = mb_QueryWithArgs(o, MBQ_GetCDInfoFromCDIndexId, args);

    if (!ret)
    {
        mb_GetQueryError(o, error, 256);
        printf("Query failed: %s\n", error);
        mb_Delete(o);
        return 0;
    }

    for(albumNum = 1;; albumNum++)
    {
        // Select the first album
        if (!mb_Select1(o, MBS_SelectAlbum, albumNum))
            break;

        // Pull back the album id to see if we got the album
        if (!mb_GetResultData(o, MBE_AlbumGetAlbumId, data, 256))
        {
            printf("Album not found.\n");
            break;
        }  
        printf("Match #: %d\n-------------------------------------------------\n", albumNum);
        mb_GetIDFromURL(o, data, temp, 256);
        printf("    AlbumId: %s\n", temp);

        // Extract the album name
        if (mb_GetResultData(o, MBE_AlbumGetAlbumName, data, 256))
           printf("       Name: %s\n", data);

        // Extract the number of tracks
        numTracks = mb_GetResultInt(o, MBE_AlbumGetNumTracks);
        if (numTracks > 0 && numTracks < 100)
           printf("  NumTracks: %d\n", numTracks);

        // Check to see if there is more than one artist for this album
        for(i = 1; i <= numTracks; i++)
        {
            if (!mb_GetResultData1(o, MBE_AlbumGetArtistId, data, 256, i))
                break;

            if (i == 1)
               strcpy(temp, data);

            if (strcmp(temp, data))
            {
                isMultipleArtist = 1;
                break;
            }
        }

        if (!isMultipleArtist)
        {
            // Extract the artist name from the album
            if (mb_GetResultData1(o, MBE_AlbumGetArtistName, data, 256, 1))
               printf("AlbumArtist: %s\n", data);
        
            // Extract the artist id from the album
            if (mb_GetResultData1(o, MBE_AlbumGetArtistId, data, 256, 1))
            {
               mb_GetIDFromURL(o, data, temp, 256);
               printf("   ArtistId: %s\n", temp);
            }
        }

        // Extract the amazon asin, if any
        if (mb_GetResultData(o, MBE_AlbumGetAmazonAsin, data, 256))
           printf("Amazon Asin: %s\n", data);

        numDates = mb_GetResultInt(o, MBE_AlbumGetNumReleaseDates);
        for(i = 1; i <= numDates; i++)
        {
            // Select the first release date
            if (mb_Select1(o, MBS_SelectReleaseDate, i))
            {
                // Pull back the release date and release country
                if (mb_GetResultData(o, MBE_ReleaseGetDate, data, 256))
                {
                    printf("   Released: %s", data);
                }  
                if (mb_GetResultData(o, MBE_ReleaseGetCountry, data, 256))
                {
                    printf(" (%s)", data);
                }  
                printf("\n");
                mb_Select(o, MBS_Back);  
            }
            else
                break;
        }
        printf("\n");

        for(i = 1; i <= numTracks; i++)
        {
            // Extract the track name from the album.
            if (mb_GetResultData1(o, MBE_AlbumGetTrackName, data, 256, i))
               printf("      Track: %s\n", data);
            else
               break;
        
            // Extract the album id from the track. Just use the
            // first album that this track appears on
            if (mb_GetResultData1(o, MBE_AlbumGetTrackId, data, 256, i))
            {
               mb_GetIDFromURL(o, data, temp, 256);
               printf("    TrackId: %s\n", temp);

               // Extract the track number
               trackNum = mb_GetOrdinalFromList(o, MBE_AlbumGetTrackList, data);
               if (trackNum > 0 && trackNum < 100)
                   printf("   TrackNum: %d\n", trackNum);
            }

            // If its a multple artist album, print out the artist for each track
            if (isMultipleArtist)
            {
               // Extract the artist name from this track
               if (mb_GetResultData1(o, MBE_AlbumGetArtistName, data, 256, i))
                  printf("TrackArtist: %s\n", data);
           
               // Extract the artist id from this track
               if (mb_GetResultData1(o, MBE_AlbumGetArtistId, data, 256, i))
               {
                  mb_GetIDFromURL(o, data, temp, 256);
                  printf("   ArtistId: %s\n", temp);
               }
            }
            printf("\n");
        }
        mb_Select(o, MBS_Back);
        printf("\n\n");
    }

#ifdef WIN32
    mb_WSAStop(o);
#endif

    // and clean up the musicbrainz object
    mb_Delete(o);

    return 0;
}
