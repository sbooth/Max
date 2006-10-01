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

     $Id: queries.h 7524 2006-05-11 19:31:24Z luks $

----------------------------------------------------------------------------*/
#ifndef _QUERIES_H_
#define _QUERIES_H_

/* -------------------------------------------------------------------------
 * Select queries -- these whitespace seperated list macros are a list of
 * rdf predicates and/or ordinals (specified as []). These predicate lists
 * specify a path to traverse through an RDF graph (comprised of statements,
 * aka triples). Each select query starts at the top level resource and
 * 'selects' another node in the rdf graph by moving through the graph
 * as specified by the predicate list. The URI of the new node, will be
 * saved as the 'selected context'. Once a context has been selected,
 * you can use the MBE_ queries below to extract metadata out of a context.
 * -------------------------------------------------------------------------
 */

/**
 * The MusicBrainz artist id used to indicate that an album is a various artist
 * album.
 */
#define MBI_VARIOUS_ARTIST_ID \
        "89ad4ac3-39f7-470e-963a-56509c546377"

/**
 * Use this query to reset the current context back to the top level of
 * the response.
 */
#define MBS_Rewind           \
        "[REWIND]"

/**
 * Use this query to change the current context back one level.
 */
#define MBS_Back           \
        "[BACK]"

/**
 * Use this Select Query to select an artist from an query that returns
 * a list of artists. Giving the argument 1 for the ordinal selects 
 * the first artist in the list, 2 the second and so on. Use 
 * MBE_ArtistXXXXXX queries to extract data after the select.
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectArtist           \
        "http://musicbrainz.org/mm/mm-2.1#artistList []"

/**
 * Use this Select Query to select an album from an query that returns
 * a list of albums. Giving the argument 1 for the ordinal selects 
 * the first album in the list, 2 the second and so on. Use
 * MBE_AlbumXXXXXX queries to extract data after the select.
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectAlbum            \
        "http://musicbrainz.org/mm/mm-2.1#albumList []"

/**
 * Use this Select Query to select an the corresponding artist from an album 
 * context. MBE_ArtistXXXXXX queries to extract data after the select.
 */
#define MBS_SelectAlbumArtist      \
        "http://purl.org/dc/elements/1.1/creator"

/**
 * Use this Select Query to select a track from an query that returns
 * a list of tracks. Giving the argument 1 for the ordinal selects 
 * the first track in the list, 2 the second and so on. Use
 * MBE_TrackXXXXXX queries to extract data after the select.
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectTrack            \
        "http://musicbrainz.org/mm/mm-2.1#trackList []"

/**
 * Use this Select Query to select an the corresponding artist from a track 
 * context. MBE_ArtistXXXXXX queries to extract data after the select.
 */
#define MBS_SelectTrackArtist      \
        "http://purl.org/dc/elements/1.1/creator"

/**
 * Use this Select Query to select an the corresponding artist from a track 
 * context. MBE_ArtistXXXXXX queries to extract data after the select.
 */
#define MBS_SelectTrackAlbum      \
        "http://musicbrainz.org/mm/mq-1.1#album"

/**
 * Use this Select Query to select a trmid from the list. 
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectTrmid           \
        "http://musicbrainz.org/mm/mm-2.1#trmidList []"

/**
 * Use this Select Query to select a CD Index id from the list. 
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectCdindexid           \
        "http://musicbrainz.org/mm/mm-2.1#cdindexidList []"

/**
 * Use this Select Query to select a Release date/country from the list. 
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectReleaseDate           \
        "http://musicbrainz.org/mm/mm-2.1#releaseDateList []"

/**
 * Use this Select Query to select a result from a lookupResultList.
 * This select will be used in conjunction with MBQ_FileLookup.
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectLookupResult            \
        "http://musicbrainz.org/mm/mq-1.1#lookupResultList []"

/**
 * Use this Select Query to select the artist from a lookup result.
 * This select will be used in conjunction with MBQ_FileLookup.
 */
#define MBS_SelectLookupResultArtist            \
        "http://musicbrainz.org/mm/mq-1.1#artist"

/**
 * Use this Select Query to select the album from a lookup result.
 * This select will be used in conjunction with MBQ_FileLookup.
 */
#define MBS_SelectLookupResultAlbum            \
        "http://musicbrainz.org/mm/mq-1.1#album"

/**
 * Use this Select Query to select the track from a lookup result.
 * This select will be used in conjunction with MBQ_FileLookup.
 */
#define MBS_SelectLookupResultTrack            \
        "http://musicbrainz.org/mm/mq-1.1#track"

/**
 * Use this Select Query to select a relationship from a list
 * of advanced relationships.
 * @param ordinal This select requires one ordinal argument
 */
#define MBS_SelectRelationship           \
        "http://musicbrainz.org/ar/ar-1.0#relationshipList []"

/* -------------------------------------------------------------------------
 * General top level queries -- Internal use only.
 * -------------------------------------------------------------------------
 */
/** 
 * Internal use only.
 */
#define MBE_QuerySubject           \
        "http://musicbrainz.org/mm/mq-1.1#Result"
/** 
 * Internal use only.
 */
#define MBE_GetError               \
        "http://musicbrainz.org/mm/mq-1.1#error"


/* -------------------------------------------------------------------------
 * Top level queries used with MBQ_FileInfoLookup 
 * -------------------------------------------------------------------------
 */

/** 
 * Get the general return status of this query. Values for this
 * include OK or fuzzy. Fuzzy is returned when the server made 
 * a fuzzy match somewhere while handling the query.
 */
#define MBE_GetStatus              \
        "http://musicbrainz.org/mm/mq-1.1#status"

/* -------------------------------------------------------------------------
 * Queries used to determine the number of items returned
 * by a query.
 * -------------------------------------------------------------------------
 */
/**
 * Return the number of artist returned in this query.
 */
#define MBE_GetNumArtists     \
        "http://musicbrainz.org/mm/mm-2.1#artistList [COUNT]"

/**
 * Return the number of albums returned in this query.
 */
#define MBE_GetNumAlbums      \
        "http://musicbrainz.org/mm/mm-2.1#albumList [COUNT]"

/**
 * Return the number of tracks returned in this query.
 */
#define MBE_GetNumTracks      \
        "http://musicbrainz.org/mm/mm-2.1#trackList [COUNT]"

/**
 * Return the number of trmids returned in this query.
 */
#define MBE_GetNumTrmids      \
        "http://musicbrainz.org/mm/mm-2.1#trmidList [COUNT]"

/**
 * Return the number of lookup results returned in this query.
 */
#define MBE_GetNumLookupResults      \
        "http://musicbrainz.org/mm/mq-1.1#lookupResultList [COUNT]"

/* -------------------------------------------------------------------------
 * artistList queries
 * -------------------------------------------------------------------------
 */

/**
 * Return the name of the currently selected Album
 */
#define MBE_ArtistGetArtistName      \
        "http://purl.org/dc/elements/1.1/title"

/**
 * Return the name of the currently selected Album
 */
#define MBE_ArtistGetArtistSortName      \
        "http://musicbrainz.org/mm/mm-2.1#sortName"

/**
 * Return the ID of the currently selected Album. The value of this
 * query is indeed empty!
 */
#define MBE_ArtistGetArtistId        \
        "" /* yes, empty! */

/**
 * Return the name of the nth album. Requires an ordinal argument to select
 * an album from a list of albums in the current artist
 * @param ordinal This select requires one ordinal argument to select an album
 */
#define MBE_ArtistGetAlbumName      \
        "http://musicbrainz.org/mm/mm-2.1#albumList [] http://purl.org/dc/elements/1.1/title"

/**
 * Return the ID of the nth album. Requires an ordinal argument to select
 * an album from a list of albums in the current artist
 * @param ordinal This select requires one ordinal argument to select an album
 */
#define MBE_ArtistGetAlbumId      \
        "http://musicbrainz.org/mm/mm-2.1#albumList []"

/* -------------------------------------------------------------------------
 * albumList queries
 * -------------------------------------------------------------------------
 */

/**
 * Return the name of the currently selected Album
 */
#define MBE_AlbumGetAlbumName      \
        "http://purl.org/dc/elements/1.1/title"

/**
 * Return the ID of the currently selected Album. The value of this
 * query is indeed empty!
 */
#define MBE_AlbumGetAlbumId        \
        "" /* yes, empty!  */

/**
 * Return the release status of the currently selected Album.
 */
#define MBE_AlbumGetAlbumStatus        \
        "http://musicbrainz.org/mm/mm-2.1#releaseStatus"

/**
 * Return the release type of the currently selected Album.
 */
#define MBE_AlbumGetAlbumType        \
        "http://musicbrainz.org/mm/mm-2.1#releaseType"

/**
 * Return the amazon asin for the selected Album.
 */
#define MBE_AlbumGetAmazonAsin        \
        "http://www.amazon.com/gp/aws/landing.html#Asin"

/**
 * Return the number of cdindexds returned in this query.
 */
#define MBE_AlbumGetNumCdindexIds    \
        "http://musicbrainz.org/mm/mm-2.1#cdindexidList [COUNT]"

/**
 * Return the nth cdindex of the album. Requires a index
 * ordinal. 1 for the first cdindex, etc...
 * @param ordinal This select requires one ordinal argument to select a cdindex
 */
#define MBE_AlbumGetCdindexId    \
        "http://musicbrainz.org/mm/mm-2.1#cdindexidList []"         
        
/**
 * Return the number of release dates returned in this query.
 */
#define MBE_AlbumGetNumReleaseDates    \
        "http://musicbrainz.org/mm/mm-2.1#releaseDateList [COUNT]"

/**
 * Return the Artist ID of the currently selected Album. This may return 
 * the artist id for the Various Artists' artist, and then you should 
 * check the artist for each track of the album seperately with MBE_AlbumGetArtistName,
 * MBE_AlbumGetArtistSortName and MBE_AlbumGetArtistId.
 */
#define MBE_AlbumGetAlbumArtistId        \
        "http://purl.org/dc/elements/1.1/creator"

/**
 * Return the name of the artist for this album.
 */
#define MBE_AlbumGetAlbumArtistName      \
        "http://purl.org/dc/elements/1.1/creator http://purl.org/dc/elements/1.1/title"

/**
 * Return the sortname of the artist for this album.
 */
#define MBE_AlbumGetAlbumArtistSortName      \
        "http://purl.org/dc/elements/1.1/creator http://musicbrainz.org/mm/mm-2.1#sortName"         
        
/**
 * Return the mumber of tracks in the currently selected Album
 */
#define MBE_AlbumGetNumTracks      \
        "http://musicbrainz.org/mm/mm-2.1#trackList [COUNT]"

/**
 * Return the Id of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetTrackId        \
        "http://musicbrainz.org/mm/mm-2.1#trackList [] "

/**
 * Return the track list of an album. This extractor should only be used
 * to specify a list for GetOrdinalFromList().
 * @see mb_GetOrdinalFromList
 */
#define MBE_AlbumGetTrackList        \
        "http://musicbrainz.org/mm/mm-2.1#trackList"

/**
 * Return the track number of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetTrackNum       \
        "http://musicbrainz.org/mm/mm-2.1#trackList [?] http://musicbrainz.org/mm/mm-2.1#trackNum"

/**
 * Return the track name of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetTrackName      \
        "http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/title"

/**
 * Return the track duration of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetTrackDuration       \
        "http://musicbrainz.org/mm/mm-2.1#trackList [] http://musicbrainz.org/mm/mm-2.1#duration"

/**
 * Return the artist name of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetArtistName     \
        "http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/creator http://purl.org/dc/elements/1.1/title"

/**
 * Return the artist sortname of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetArtistSortName \
        "http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/creator http://musicbrainz.org/mm/mm-2.1#sortName"

/**
 * Return the artist Id of the nth track in the album. Requires a
 * track index ordinal. 1 for the first track, etc...
 * @param ordinal This select requires one ordinal argument to select a track
 */
#define MBE_AlbumGetArtistId       \
        "http://musicbrainz.org/mm/mm-2.1#trackList [] http://purl.org/dc/elements/1.1/creator"

/* -------------------------------------------------------------------------
 * trackList queries
 * -------------------------------------------------------------------------
 */

/**
 * Return the name of the currently selected track
 */
#define MBE_TrackGetTrackName      \
        "http://purl.org/dc/elements/1.1/title"

/**
 * Return the ID of the currently selected track. The value of this
 * query is indeed empty!
 */
#define MBE_TrackGetTrackId        \
        "" /* yes, empty! */

/**
 * Return the track number in the currently selected track
 */
#define MBE_TrackGetTrackNum      \
        "http://musicbrainz.org/mm/mm-2.1#trackNum"

/**
 * Return the track duration in the currently selected track
 */
#define MBE_TrackGetTrackDuration \
        "http://musicbrainz.org/mm/mm-2.1#duration"

/**
 * Return the name of the artist for this track. 
 */
#define MBE_TrackGetArtistName      \
        "http://purl.org/dc/elements/1.1/creator http://purl.org/dc/elements/1.1/title"

/**
 * Return the sortname of the artist for this track. 
 */
#define MBE_TrackGetArtistSortName      \
        "http://purl.org/dc/elements/1.1/creator http://musicbrainz.org/mm/mm-2.1#sortName"

/**
 * Return the Id of the artist for this track. 
 */
#define MBE_TrackGetArtistId      \
        "http://purl.org/dc/elements/1.1/creator"

/* -------------------------------------------------------------------------
 * Quick track queries
 * -------------------------------------------------------------------------
 */

/**
 * Return the name of the aritst
 */
#define MBE_QuickGetArtistName      \
        "http://musicbrainz.org/mm/mq-1.1#artistName"

/**
 * Return the sortname of the aritst
 */
#define MBE_QuickGetArtistSortName      \
        "http://musicbrainz.org/mm/mm-2.1#sortName"

/**
 * Return the id of the artist
 */
#define MBE_QuickGetArtistId      \
        "http://musicbrainz.org/mm/mm-2.1#artistid"

/**
 * Return the name of the aritst
 */
#define MBE_QuickGetAlbumName      \
        "http://musicbrainz.org/mm/mq-1.1#albumName"

/**
 * Return the name of the aritst
 */
#define MBE_QuickGetTrackName      \
        "http://musicbrainz.org/mm/mq-1.1#trackName"

/**
 * Return the name of the aritst
 */
#define MBE_QuickGetTrackNum       \
        "http://musicbrainz.org/mm/mm-2.1#trackNum"

/**
 * Return the MB track id
 */
#define MBE_QuickGetTrackId       \
        "http://musicbrainz.org/mm/mm-2.1#trackid"

/**
 * Return the track duration
 */
#define MBE_QuickGetTrackDuration       \
        "http://musicbrainz.org/mm/mm-2.1#duration"

/* -------------------------------------------------------------------------
 * Release date / country queries
 * -------------------------------------------------------------------------
 */

/**
 * Return the release date
 */
#define MBE_ReleaseGetDate       \
        "http://purl.org/dc/elements/1.1/date"

/**
 * Return the release country
 */
#define MBE_ReleaseGetCountry       \
        "http://musicbrainz.org/mm/mm-2.1#country"

/* -------------------------------------------------------------------------
 * FileLookup queries
 * -------------------------------------------------------------------------
 */

/**
 * Return the type of the lookup result
 */
#define MBE_LookupGetType      \
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

/**
 * Return the relevance of the lookup result
 */
#define MBE_LookupGetRelevance      \
        "http://musicbrainz.org/mm/mq-1.1#relevance"

/**
 * Return the artist id of the lookup result
 */
#define MBE_LookupGetArtistId      \
        "http://musicbrainz.org/mm/mq-1.1#artist"

/**
 * Return the artist id of the lookup result
 */
#define MBE_LookupGetAlbumId      \
        "http://musicbrainz.org/mm/mq-1.1#album"

/**
 * Return the artist id of the lookup result
 */
#define MBE_LookupGetAlbumArtistId      \
        "http://musicbrainz.org/mm/mq-1.1#album " \
        "http://purl.org/dc/elements/1.1/creator"

/**
 * Return the track id of the lookup result
 */
#define MBE_LookupGetTrackId      \
        "http://musicbrainz.org/mm/mq-1.1#track"

/**
 * Return the artist id of the lookup result
 */
#define MBE_LookupGetTrackArtistId      \
        "http://musicbrainz.org/mm/mq-1.1#track " \
        "http://purl.org/dc/elements/1.1/creator"

/* -------------------------------------------------------------------------
 * Extract queries for the MBQ_GetXXXXXRelationsById queries
 * -------------------------------------------------------------------------
 */

/**
 * Get the type of an advanced relationships link. Please note that these
 * relationship types can change over time!
 */
#define MBE_GetRelationshipType \
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

/**
 * Get the direction of a link between two like entities. This
 * data element will only be present for links between like types
 * (eg artist-artist links) and IFF the link direction is 
 * reverse of what the RDF implies.
 */
#define MBE_GetRelationshipDirection \
        "http://musicbrainz.org/ar/ar-1.0#direction"

/**
 * Get the artist id that this link points to.
 */
#define MBE_GetRelationshipArtistId \
        "http://musicbrainz.org/ar/ar-1.0#toArtist"

/**
 * Get the artist name that this link points to.
 */
#define MBE_GetRelationshipArtistName \
        "http://musicbrainz.org/ar/ar-1.0#toArtist http://purl.org/dc/elements/1.1/title"

/**
 * Get the album id that this link points to.
 */
#define MBE_GetRelationshipAlbumId \
        "http://musicbrainz.org/ar/ar-1.0#toAlbum"

/**
 * Get the album name that this link points to.
 */
#define MBE_GetRelationshipAlbumName \
        "http://musicbrainz.org/ar/ar-1.0#toAlbum http://purl.org/dc/elements/1.1/title"

/**
 * Get the track id that this link points to.
 */
#define MBE_GetRelationshipTrackId \
        "http://musicbrainz.org/ar/ar-1.0#toTrack"

/**
 * Get the track name that this link points to.
 */
#define MBE_GetRelationshipTrackName \
        "http://musicbrainz.org/ar/ar-1.0#toTrack http://purl.org/dc/elements/1.1/title"

/**
 * Get the URL that this link points to.
 */
#define MBE_GetRelationshipURL \
        "http://musicbrainz.org/ar/ar-1.0#toUrl"

/**
 * Get the vocal/instrument attributes. Must pass an ordinal to indicate which attribute to get.
 */
#define MBE_GetRelationshipAttribute \
        "http://musicbrainz.org/ar/ar-1.0#attributeList []"

/* -------------------------------------------------------------------------
 * Extract queries for the MBQ_GetCDTOC query
 * -------------------------------------------------------------------------
 */
/**
 * return the CDIndex ID from the table of contents from the CD
 */
#define MBE_TOCGetCDIndexId           \
        "http://musicbrainz.org/mm/mm-2.1#cdindexid"
/**
 * return the first track number from the table of contents from the CD
 */
#define MBE_TOCGetFirstTrack          \
        "http://musicbrainz.org/mm/mm-2.1#firstTrack"
/**
 * return the last track number (total number of tracks on the CD) 
 * from the table of contents from the CD
 */
#define MBE_TOCGetLastTrack           \
        "http://musicbrainz.org/mm/mm-2.1#lastTrack"
/**
 * return the sector offset from the nth track. One ordinal argument must
 * be given to specify the track. Track 1 is a special lead-out track,
 * and the actual track 1 on a CD can be retrieved as track 2 and so forth.
 */
#define MBE_TOCGetTrackSectorOffset   \
        "http://musicbrainz.org/mm/mm-2.1#toc [] http://musicbrainz.org/mm/mm-2.1#sectorOffset"
/**
 * return the number of sectors for the nth track. One ordinal argument must
 * be given to specify the track. Track 1 is a special lead-out track,
 * and the actual track 1 on a CD can be retrieved as track 2 and so forth.
 */
#define MBE_TOCGetTrackNumSectors     \
        "http://musicbrainz.org/mm/mm-2.1#toc [] http://musicbrainz.org/mm/mm-2.1#numSectors"

/* -------------------------------------------------------------------------
 * Extract queries for the MBQ_AuthenticateQuery query
 * -------------------------------------------------------------------------
 */
/**
 * return the Session Id from the Auth Query. This query will be used 
 * internally by the client library.
 */
#define MBE_AuthGetSessionId  \
        "http://musicbrainz.org/mm/mq-1.1#sessionId"

/**
 * return the Auth Challenge data from the Auth Query This query will be used 
 * internally by the client library.
 */
#define MBE_AuthGetChallenge  \
        "http://musicbrainz.org/mm/mq-1.1#authChallenge"

/* -------------------------------------------------------------------------
 * Local queries (queries are automatically generated)
 * -------------------------------------------------------------------------
 */
/**
 * Use this query to look up a CD from MusicBrainz. This query will
 * examine the CD-ROM in the CD-ROM drive specified by mb_SetDevice
 * and then send the CD-ROM data to the server. The server will then
 * find any matching CDs and return then as an albumList.
 */
#define MBQ_GetCDInfo              \
        "@CDINFO@"
/**
 * Use this query to examine the table of contents of a CD. This query will
 * examine the CD-ROM in the CD-ROM drive specified by mb_SetDevice, and
 * then let the use extract data from the table of contents using the
 * MBQ_TOCXXXXX functions. No live net connection is required for this query.
 */
#define MBQ_GetCDTOC               \
        "@LOCALCDINFO@"
/**
 * Internal use only. (For right now)
 */
#define MBQ_AssociateCD            \
        "@CDINFOASSOCIATECD@"

/* -------------------------------------------------------------------------
 * Server queries (queries must have argument(s) substituted in them)
 * -------------------------------------------------------------------------
 */

/**
 * This query is use to start an authenticated session with the MB server.
 * The username is sent to the server, and the server responds with 
 * session id and a challenge sequence that the client needs to use to create 
 * a session key. The session key and session id need to be provided with
 * the MBQ_SubmitXXXX functions in order to give moderators/users credit
 * for their submissions. This query will be carried out by the client
 * libary automatically -- you should not need to use it.
 * @param username -- the name of the user who would like to submit data.
 */
#define MBQ_Authenticate \
    "<mq:AuthenticateQuery>\n" \
    "   <mq:username>@1@</mq:username>\n" \
    "</mq:AuthenticateQuery>\n" 

/**
 * Use this query to return an albumList for the given CD Index Id
 * @param cdindexid The cdindex id to look up at the remote server.
 */
#define MBQ_GetCDInfoFromCDIndexId \
    "<mq:GetCDInfo>\n" \
    "   <mq:depth>@DEPTH@</mq:depth>\n" \
    "   <mm:cdindexid>@1@</mm:cdindexid>\n" \
    "</mq:GetCDInfo>\n" 

/**
 * Use this query to return the metadata information (artistname,
 * albumname, trackname, tracknumber) for a given trm id. Optionally, 
 * you can also specifiy the basic artist metadata, so that if the server
 * cannot match on the TRM id, it will attempt to match based on the basic
 * metadata.
 * In case of a TRM collision (where one TRM may point to more than one track)
 * this function will return more than on track. The user (or tagging app)
 * must decide which track information is correct.
 * @param trmid The TRM id for the track to be looked up
 * @param artistName The name of the artist
 * @param albumName The name of the album
 * @param trackName The name of the track
 * @param trackNum The number of the track
 */
#define MBQ_TrackInfoFromTRMId \
    "<mq:TrackInfoFromTRMId>\n" \
    "   <mm:trmid>@1@</mm:trmid>\n" \
    "   <mq:artistName>@2@</mq:artistName>\n" \
    "   <mq:albumName>@3@</mq:albumName>\n" \
    "   <mq:trackName>@4@</mq:trackName>\n" \
    "   <mm:trackNum>@5@</mm:trackNum>\n" \
    "   <mm:duration>@6@</mm:duration>\n" \
    "</mq:TrackInfoFromTRMId>\n" 

/**
 * Use this query to return the basic metadata information (artistname,
 * albumname, trackname, tracknumber) for a given track mb id
 * @param trackid The MB track id for the track to be looked up
 */
#define MBQ_QuickTrackInfoFromTrackId \
    "<mq:QuickTrackInfoFromTrackId>\n" \
    "   <mm:trackid>@1@</mm:trackid>\n" \
    "   <mm:albumid>@2@</mm:albumid>\n" \
    "</mq:QuickTrackInfoFromTrackId>\n" 

/**
 * Use this query to find artists by name. This function returns an artistList 
 * for the given artist name.
 * @param artistName The name of the artist to find.
 */
#define MBQ_FindArtistByName \
    "<mq:FindArtist>\n" \
    "   <mq:depth>@DEPTH@</mq:depth>\n" \
    "   <mq:artistName>@1@</mq:artistName>\n" \
    "   <mq:maxItems>@MAX_ITEMS@</mq:maxItems>\n" \
    "</mq:FindArtist>\n" 

/**
 * Use this query to find albums by name. This function returns an albumList 
 * for the given album name. 
 * @param albumName The name of the album to find.
 */
#define MBQ_FindAlbumByName \
    "<mq:FindAlbum>\n" \
    "   <mq:depth>@DEPTH@</mq:depth>\n" \
    "   <mq:maxItems>@MAX_ITEMS@</mq:maxItems>\n" \
    "   <mq:albumName>@1@</mq:albumName>\n" \
    "</mq:FindAlbum>\n" 

/**
 * Use this query to find tracks by name. This function returns a trackList 
 * for the given track name. 
 * @param trackName The name of the track to find.
 */
#define MBQ_FindTrackByName \
    "<mq:FindTrack>\n" \
    "   <mq:depth>@DEPTH@</mq:depth>\n" \
    "   <mq:maxItems>@MAX_ITEMS@</mq:maxItems>\n" \
    "   <mq:trackName>@1@</mq:trackName>\n" \
    "</mq:FindTrack>\n" 

/**
 * Use this function to find TRM Ids that match a given artistName
 * and trackName, This query returns a trmidList.
 * @param artistName The name of the artist to find.
 * @param trackName The name of the track to find.
 */
#define MBQ_FindDistinctTRMId \
    "<mq:FindDistinctTRMID>\n" \
    "   <mq:depth>@DEPTH@</mq:depth>\n" \
    "   <mq:artistName>@1@</mq:artistName>\n" \
    "   <mq:trackName>@2@</mq:trackName>\n" \
    "</mq:FindDistinctTRMID>\n" 

/** 
 * Retrieve an artistList from a given Artist id 
 */
#define MBQ_GetArtistById \
    "http://@URL@/mm-2.1/artist/@1@/@DEPTH@" 

/** 
 * Retrieve an albumList from a given Album id 
 */
#define MBQ_GetAlbumById \
    "http://@URL@/mm-2.1/album/@1@/@DEPTH@" 

/** 
 * Retrieve an trackList from a given Track id 
 */
#define MBQ_GetTrackById \
    "http://@URL@/mm-2.1/track/@1@/@DEPTH@" 

/** 
 * Retrieve an trackList from a given TRM Id 
 */
#define MBQ_GetTrackByTRMId \
    "http://@URL@/mm-2.1/trmid/@1@/@DEPTH@" 

/** 
 * Retrieve an artistList with advanced relationships from a given artist id
 */
#define MBQ_GetArtistRelationsById \
    "http://@URL@/mm-2.1/artistrel/@1@" 

/** 
 * Retrieve an albumList with advanced relationships from a given album id
 */
#define MBQ_GetAlbumRelationsById \
    "http://@URL@/mm-2.1/albumrel/@1@" 

/** 
 * Retrieve a trackList with advanced relationships from a given track id
 */
#define MBQ_GetTrackRelationsById \
    "http://@URL@/mm-2.1/trackrel/@1@" 

/** 
 * Internal use only.
 */
#define MBQ_SubmitTrack \
    "<mq:SubmitTrack>\n" \
    "   <mq:artistName>@1@</mq:artistName>\n" \
    "   <mq:albumName>@2@</mq:albumName>\n" \
    "   <mq:trackName>@3@</mq:trackName>\n" \
    "   <mm:trmid>@4@</mm:trmid>\n" \
    "   <mm:trackNum>@5@</mm:trackNum>\n" \
    "   <mm:duration>@6@</mm:duration>\n" \
    "   <mm:issued>@7@</mm:issued>\n" \
    "   <mm:genre>@8@</mm:genre>\n" \
    "   <dc:description>@9@</dc:description>\n" \
    "   <mm:link>@10@</mm:link>\n" \
    "   <mq:sessionId>@SESSID@</mq:sessionId>\n" \
    "   <mq:sessionKey>@SESSKEY@</mq:sessionKey>\n" \
    "</mq:SubmitTrack>\n" 

/** 
 * Submit a single TrackId, TRM Id pair to MusicBrainz. This query can
 * handle only one pair at a time, which is inefficient. The user may wish
 * to create the query RDF text by hand and provide more than one pair
 * in the rdf:Bag, since the server can handle up to 1000 pairs in one
 * query.
 * @param TrackGID  The Global ID field of the track
 * @param trmid     The TRM Id of the track.
 */
#define MBQ_SubmitTrackTRMId \
    "<mq:SubmitTRMList>\n" \
    " <mm:trmidList>\n" \
    "  <rdf:Bag>\n" \
    "   <rdf:li>\n" \
    "    <mq:trmTrackPair>\n" \
    "     <mm:trackid>@1@</mm:trackid>\n" \
    "     <mm:trmid>@2@</mm:trmid>\n" \
    "    </mq:trmTrackPair>\n" \
    "   </rdf:li>\n" \
    "  </rdf:Bag>\n" \
    " </mm:trmidList>\n" \
    " <mq:sessionId>@SESSID@</mq:sessionId>\n" \
    " <mq:sessionKey>@SESSKEY@</mq:sessionKey>\n" \
    " <mq:clientVersion>@CLIENTVER@</mq:clientVersion>\n" \
    "</mq:SubmitTRMList>\n" 

/** 
 * Lookup metadata for one file. This function can be used by tagging applications
 * to attempt to match a given track with a track in the database. The server will
 * attempt to match an artist, album and track during three phases. If 
 * at any one lookup phase the server finds ONE item only, it will move on to
 * to the next phase. If no items are returned, an error message is returned. If 
 * more then one item is returned, the end-user will have to choose one from
 * the returned list and then make another call to the server. To express the
 * choice made by a user, the client should leave the artistName/albumName empty and 
 * provide the artistId and/or albumId empty on the subsequent call. Once an artistId
 * or albumId is provided the server will pick up from the given Ids and attempt to
 * resolve the next phase.
 * @param ArtistName The name of the artist, gathered from ID3 tags or user input
 * @param AlbumName  The name of the album, also from ID3 or user input
 * @param TrackName  The name of the track
 * @param TrackNum   The track number of the track being matched
 * @param Duration   The duration of the track being matched
 * @param FileName   The name of the file that is being matched. This will only be used
 *                   if the ArtistName, AlbumName or TrackName fields are blank. 
 * @param ArtistId   The AritstId resolved from an earlier call. 
 * @param AlbumId    The AlbumId resolved from an earlier call. 
 * @param MaxItems   The maximum number of items to return if the server cannot
 *                   determine an exact match.
 */
#define MBQ_FileInfoLookup \
    "<mq:FileInfoLookup>\n" \
    "   <mm:trmid>@1@</mm:trmid>\n" \
    "   <mq:artistName>@2@</mq:artistName>\n" \
    "   <mq:albumName>@3@</mq:albumName>\n" \
    "   <mq:trackName>@4@</mq:trackName>\n" \
    "   <mm:trackNum>@5@</mm:trackNum>\n" \
    "   <mm:duration>@6@</mm:duration>\n" \
    "   <mq:fileName>@7@</mq:fileName>\n" \
    "   <mm:artistid>@8@</mm:artistid>\n" \
    "   <mm:albumid>@9@</mm:albumid>\n" \
    "   <mm:trackid>@10@</mm:trackid>\n" \
    "   <mq:maxItems>@MAX_ITEMS@</mq:maxItems>\n" \
    "</mq:FileInfoLookup>\n" 

#endif
