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

     $Id: getrels.c 763 2005-11-09 21:45:12Z robert $

----------------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "musicbrainz/mb_c.h"

int main(int argc, char *argv[])
{
    musicbrainz_t o;
    char          error[256], data[256], temp[256], *args[2];
    int           ret, relNum, attrNum;
    char         *squery = NULL;

    if (argc < 3)
    {
        printf("Usage: getrels <artist|album|track> <uuid>\n");
        exit(0);
    }

    /* Create the musicbrainz object, which will be needed for subsequent calls */
    o = mb_New();

#ifdef WIN32
    mb_WSAInit(o);
#endif

    /* Tell the client library to return data in ISO8859-1 and not UTF-8 */
    mb_UseUTF8(o, 0);

    /* Set the proper server to use. Defaults to mm.musicbrainz.org:80 */
    if (getenv("MB_SERVER"))
        mb_SetServer(o, getenv("MB_SERVER"), 80);

    /* Check to see if the debug env var has been set */
    if (getenv("MB_DEBUG"))
        mb_SetDebug(o, atoi(getenv("MB_DEBUG")));

    /* Tell the server to only return 2 levels of data, unless the MB_DEPTH env var is set */
    if (getenv("MB_DEPTH"))
        mb_SetDepth(o, atoi(getenv("MB_DEPTH")));
    else
        mb_SetDepth(o, 4);

    /* Set up the args for the find album query */
    args[0] = argv[2];
    args[1] = NULL;

    if (strcmp(argv[1], "artist") == 0)
        ret = mb_QueryWithArgs(o, MBQ_GetArtistRelationsById, args);
    else
    if (strcmp(argv[1], "album") == 0)
        ret = mb_QueryWithArgs(o, MBQ_GetAlbumRelationsById, args);
    else
    if (strcmp(argv[1], "track") == 0)
        ret = mb_QueryWithArgs(o, MBQ_GetTrackRelationsById, args);
    else
    {
        printf("Invalid first argument: '%s', Must be artist, album or track.\n",argv[1]);
        exit(0);
    }

    if (!ret)
    {
        mb_GetQueryError(o, error, 256);
        printf("Query failed: %s\n", error);
        mb_Delete(o);
        return 0;
    }

    /* Select the first item in the list */
    if (strcmp(argv[1], "artist") == 0)
        squery = MBS_SelectArtist;
    else
    if (strcmp(argv[1], "album") == 0)
        squery = MBS_SelectAlbum;
    else
    if (strcmp(argv[1], "track") == 0)
        squery = MBS_SelectTrack;

    if (!mb_Select1(o, squery, 1))
    {
        printf("Cannot select first item in results\n");
        mb_Delete(o);
        return 0;
    }
    /* Pull back the item id to see if we got the album */
    if (!mb_GetResultData(o, "", data, 256))
    {
        printf("Album not found.\n");
        mb_Delete(o);
        return 0;
    }  
    mb_GetIDFromURL(o, data, temp, 256);
    printf("    AlbumId: %s\n-------------------------------------------------\n\n", temp);

    for(relNum = 1;; relNum++)
    {
        if (!mb_Select1(o, MBS_SelectRelationship, relNum))
            break;

        mb_GetResultData(o, MBE_GetRelationshipType, data, 256);
        mb_GetFragmentFromURL(o, data, temp, 255);
        printf("       Type: %s\n", temp);
        if (mb_GetResultData(o, MBE_GetRelationshipArtistId, data, 256))
        {
            mb_GetIDFromURL(o, data, temp, 255);
            mb_GetResultData(o, MBE_GetRelationshipArtistName, data, 256);
            printf("     Artist: %s\n", data);
            printf("   ArtistId: %s\n", temp);
        }
        if (mb_GetResultData(o, MBE_GetRelationshipAlbumId, data, 256))
        {
            mb_GetIDFromURL(o, data, temp, 255);
            mb_GetResultData(o, MBE_GetRelationshipAlbumName, data, 256);
            printf("      Album: %s\n", data);
            printf("    AlbumId: %s\n", temp);
        }
        if (mb_GetResultData(o, MBE_GetRelationshipTrackId, data, 256))
        {
            mb_GetIDFromURL(o, data, temp, 255);
            mb_GetResultData(o, MBE_GetRelationshipTrackName, data, 256);
            printf("      Track: %s\n", data);
            printf("    TrackId: %s\n", temp);
        }
        if (mb_GetResultData(o, MBE_GetRelationshipURL, data, 256))
        {
            printf("        URL: %s\n", data);
        }
        if (mb_GetResultData(o, MBE_GetRelationshipDirection, data, 256))
        {
            mb_GetFragmentFromURL(o, data, temp, 255);
            printf("  Direction: %s\n", temp);
        }
        for(attrNum = 1;; attrNum++)
        {
            if (mb_GetResultData1(o, MBE_GetRelationshipAttribute, data, 256, attrNum))
            {
                mb_GetFragmentFromURL(o, data, temp, 255);
                printf("  Attribute: %s\n", temp);
            }
            else
                break;
        }

        printf("\n");
        mb_Select1(o, MBS_Back, 2);
    }

#ifdef WIN32
    mb_WSAStop(o);
#endif

    /* and clean up the musicbrainz object */
    mb_Delete(o);

    return 0;
}
