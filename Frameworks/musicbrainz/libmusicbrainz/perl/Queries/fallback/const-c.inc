#define PERL_constant_NOTFOUND	1
#define PERL_constant_NOTDEF	2
#define PERL_constant_ISIV	3
#define PERL_constant_ISNO	4
#define PERL_constant_ISNV	5
#define PERL_constant_ISPV	6
#define PERL_constant_ISPVN	7
#define PERL_constant_ISSV	8
#define PERL_constant_ISUNDEF	9
#define PERL_constant_ISUV	10
#define PERL_constant_ISYES	11

#ifndef NVTYPE
typedef double NV; /* 5.6 and later define NVTYPE, and typedef NV to it.  */
#endif
#ifndef aTHX_
#define aTHX_ /* 5.6 or later define this for threading support.  */
#endif
#ifndef pTHX_
#define pTHX_ /* 5.6 or later define this for threading support.  */
#endif

static int
constant_15 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBQ_AssociateCD MBQ_SubmitTrack MBS_SelectAlbum MBS_SelectTrack
     MBS_SelectTrmid */
  /* Offset 12 gives the best switch position.  */
  switch (name[12]) {
  case 'a':
    if (memEQ(name, "MBQ_SubmitTrack", 15)) {
    /*                           ^         */
#ifdef MBQ_SubmitTrack
      *pv_return = MBQ_SubmitTrack;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBS_SelectTrack", 15)) {
    /*                           ^         */
#ifdef MBS_SelectTrack
      *pv_return = MBS_SelectTrack;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'b':
    if (memEQ(name, "MBS_SelectAlbum", 15)) {
    /*                           ^         */
#ifdef MBS_SelectAlbum
      *pv_return = MBS_SelectAlbum;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'e':
    if (memEQ(name, "MBQ_AssociateCD", 15)) {
    /*                           ^         */
#ifdef MBQ_AssociateCD
      *pv_return = MBQ_AssociateCD;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBS_SelectTrmid", 15)) {
    /*                           ^         */
#ifdef MBS_SelectTrmid
      *pv_return = MBS_SelectTrmid;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_16 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_GetNumAlbums MBE_GetNumTracks MBE_GetNumTrmids MBE_QuerySubject
     MBQ_Authenticate MBQ_GetAlbumById MBQ_GetTrackById MBS_SelectArtist */
  /* Offset 14 gives the best switch position.  */
  switch (name[14]) {
  case 'I':
    if (memEQ(name, "MBQ_GetAlbumById", 16)) {
    /*                             ^        */
#ifdef MBQ_GetAlbumById
      *pv_return = MBQ_GetAlbumById;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBQ_GetTrackById", 16)) {
    /*                             ^        */
#ifdef MBQ_GetTrackById
      *pv_return = MBQ_GetTrackById;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'c':
    if (memEQ(name, "MBE_QuerySubject", 16)) {
    /*                             ^        */
#ifdef MBE_QuerySubject
      *pv_return = MBE_QuerySubject;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'd':
    if (memEQ(name, "MBE_GetNumTrmids", 16)) {
    /*                             ^        */
#ifdef MBE_GetNumTrmids
      *pv_return = MBE_GetNumTrmids;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBE_GetNumTracks", 16)) {
    /*                             ^        */
#ifdef MBE_GetNumTracks
      *pv_return = MBE_GetNumTracks;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBE_GetNumAlbums", 16)) {
    /*                             ^        */
#ifdef MBE_GetNumAlbums
      *pv_return = MBE_GetNumAlbums;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 's':
    if (memEQ(name, "MBS_SelectArtist", 16)) {
    /*                             ^        */
#ifdef MBS_SelectArtist
      *pv_return = MBS_SelectArtist;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 't':
    if (memEQ(name, "MBQ_Authenticate", 16)) {
    /*                             ^        */
#ifdef MBQ_Authenticate
      *pv_return = MBQ_Authenticate;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_17 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_GetNumArtists MBE_LookupGetType MBQ_GetArtistById */
  /* Offset 9 gives the best switch position.  */
  switch (name[9]) {
  case 'm':
    if (memEQ(name, "MBE_GetNumArtists", 17)) {
    /*                        ^              */
#ifdef MBE_GetNumArtists
      *pv_return = MBE_GetNumArtists;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'p':
    if (memEQ(name, "MBE_LookupGetType", 17)) {
    /*                        ^              */
#ifdef MBE_LookupGetType
      *pv_return = MBE_LookupGetType;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 't':
    if (memEQ(name, "MBQ_GetArtistById", 17)) {
    /*                        ^              */
#ifdef MBQ_GetArtistById
      *pv_return = MBQ_GetArtistById;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_19 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetAlbumId MBE_AlbumGetTrackId MBE_QuickGetTrackId
     MBE_TOCGetCDIndexId MBE_TOCGetLastTrack MBE_TrackGetTrackId
     MBQ_FindAlbumByName MBQ_FindTrackByName MBQ_GetTrackByTRMId
     MBS_SelectCdindexid */
  /* Offset 12 gives the best switch position.  */
  switch (name[12]) {
  case 'A':
    if (memEQ(name, "MBE_AlbumGetAlbumId", 19)) {
    /*                           ^             */
#ifdef MBE_AlbumGetAlbumId
      *pv_return = MBE_AlbumGetAlbumId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'B':
    if (memEQ(name, "MBQ_GetTrackByTRMId", 19)) {
    /*                           ^             */
#ifdef MBQ_GetTrackByTRMId
      *pv_return = MBQ_GetTrackByTRMId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'I':
    if (memEQ(name, "MBE_TOCGetCDIndexId", 19)) {
    /*                           ^             */
#ifdef MBE_TOCGetCDIndexId
      *pv_return = MBE_TOCGetCDIndexId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'T':
    if (memEQ(name, "MBE_AlbumGetTrackId", 19)) {
    /*                           ^             */
#ifdef MBE_AlbumGetTrackId
      *pv_return = MBE_AlbumGetTrackId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetTrackId", 19)) {
    /*                           ^             */
#ifdef MBE_QuickGetTrackId
      *pv_return = MBE_QuickGetTrackId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetTrackId", 19)) {
    /*                           ^             */
#ifdef MBE_TrackGetTrackId
      *pv_return = MBE_TrackGetTrackId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'i':
    if (memEQ(name, "MBS_SelectCdindexid", 19)) {
    /*                           ^             */
#ifdef MBS_SelectCdindexid
      *pv_return = MBS_SelectCdindexid;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBQ_FindTrackByName", 19)) {
    /*                           ^             */
#ifdef MBQ_FindTrackByName
      *pv_return = MBQ_FindTrackByName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBQ_FindAlbumByName", 19)) {
    /*                           ^             */
#ifdef MBQ_FindAlbumByName
      *pv_return = MBQ_FindAlbumByName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 's':
    if (memEQ(name, "MBE_TOCGetLastTrack", 19)) {
    /*                           ^             */
#ifdef MBE_TOCGetLastTrack
      *pv_return = MBE_TOCGetLastTrack;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_20 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetArtistId MBE_AlbumGetTrackNum MBE_ArtistGetAlbumId
     MBE_AuthGetChallenge MBE_AuthGetSessionId MBE_LookupGetAlbumId
     MBE_LookupGetTrackId MBE_QuickGetArtistId MBE_QuickGetTrackNum
     MBE_TOCGetFirstTrack MBE_TrackGetArtistId MBE_TrackGetTrackNum
     MBQ_FindArtistByName MBQ_SubmitTrackTRMId MBS_SelectTrackAlbum */
  /* Offset 16 gives the best switch position.  */
  switch (name[16]) {
  case 'N':
    if (memEQ(name, "MBQ_FindArtistByName", 20)) {
    /*                               ^          */
#ifdef MBQ_FindArtistByName
      *pv_return = MBQ_FindArtistByName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "MBQ_SubmitTrackTRMId", 20)) {
    /*                               ^          */
#ifdef MBQ_SubmitTrackTRMId
      *pv_return = MBQ_SubmitTrackTRMId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'c':
    if (memEQ(name, "MBE_LookupGetTrackId", 20)) {
    /*                               ^          */
#ifdef MBE_LookupGetTrackId
      *pv_return = MBE_LookupGetTrackId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'e':
    if (memEQ(name, "MBE_AuthGetChallenge", 20)) {
    /*                               ^          */
#ifdef MBE_AuthGetChallenge
      *pv_return = MBE_AuthGetChallenge;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBE_AlbumGetTrackNum", 20)) {
    /*                               ^          */
#ifdef MBE_AlbumGetTrackNum
      *pv_return = MBE_AlbumGetTrackNum;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetTrackNum", 20)) {
    /*                               ^          */
#ifdef MBE_QuickGetTrackNum
      *pv_return = MBE_QuickGetTrackNum;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetTrackNum", 20)) {
    /*                               ^          */
#ifdef MBE_TrackGetTrackNum
      *pv_return = MBE_TrackGetTrackNum;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'l':
    if (memEQ(name, "MBS_SelectTrackAlbum", 20)) {
    /*                               ^          */
#ifdef MBS_SelectTrackAlbum
      *pv_return = MBS_SelectTrackAlbum;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'o':
    if (memEQ(name, "MBE_AuthGetSessionId", 20)) {
    /*                               ^          */
#ifdef MBE_AuthGetSessionId
      *pv_return = MBE_AuthGetSessionId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'r':
    if (memEQ(name, "MBE_TOCGetFirstTrack", 20)) {
    /*                               ^          */
#ifdef MBE_TOCGetFirstTrack
      *pv_return = MBE_TOCGetFirstTrack;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 's':
    if (memEQ(name, "MBE_AlbumGetArtistId", 20)) {
    /*                               ^          */
#ifdef MBE_AlbumGetArtistId
      *pv_return = MBE_AlbumGetArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetArtistId", 20)) {
    /*                               ^          */
#ifdef MBE_QuickGetArtistId
      *pv_return = MBE_QuickGetArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetArtistId", 20)) {
    /*                               ^          */
#ifdef MBE_TrackGetArtistId
      *pv_return = MBE_TrackGetArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'u':
    if (memEQ(name, "MBE_ArtistGetAlbumId", 20)) {
    /*                               ^          */
#ifdef MBE_ArtistGetAlbumId
      *pv_return = MBE_ArtistGetAlbumId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_LookupGetAlbumId", 20)) {
    /*                               ^          */
#ifdef MBE_LookupGetAlbumId
      *pv_return = MBE_LookupGetAlbumId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_21 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetAlbumName MBE_AlbumGetAlbumType MBE_AlbumGetNumTracks
     MBE_AlbumGetTrackList MBE_AlbumGetTrackName MBE_ArtistGetArtistId
     MBE_LookupGetArtistId MBE_QuickGetAlbumName MBE_QuickGetTrackName
     MBE_ReleaseGetCountry MBE_TrackGetTrackName MBI_VARIOUS_ARTIST_ID
     MBQ_FindDistinctTRMId MBS_SelectReleaseDate MBS_SelectTrackArtist */
  /* Offset 13 gives the best switch position.  */
  switch (name[13]) {
  case 'A':
    if (memEQ(name, "MBE_ArtistGetArtistId", 21)) {
    /*                            ^              */
#ifdef MBE_ArtistGetArtistId
      *pv_return = MBE_ArtistGetArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_LookupGetArtistId", 21)) {
    /*                            ^              */
#ifdef MBE_LookupGetArtistId
      *pv_return = MBE_LookupGetArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "MBI_VARIOUS_ARTIST_ID", 21)) {
    /*                            ^              */
#ifdef MBI_VARIOUS_ARTIST_ID
      *pv_return = MBI_VARIOUS_ARTIST_ID;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'c':
    if (memEQ(name, "MBS_SelectTrackArtist", 21)) {
    /*                            ^              */
#ifdef MBS_SelectTrackArtist
      *pv_return = MBS_SelectTrackArtist;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'e':
    if (memEQ(name, "MBS_SelectReleaseDate", 21)) {
    /*                            ^              */
#ifdef MBS_SelectReleaseDate
      *pv_return = MBS_SelectReleaseDate;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'l':
    if (memEQ(name, "MBE_AlbumGetAlbumName", 21)) {
    /*                            ^              */
#ifdef MBE_AlbumGetAlbumName
      *pv_return = MBE_AlbumGetAlbumName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_AlbumGetAlbumType", 21)) {
    /*                            ^              */
#ifdef MBE_AlbumGetAlbumType
      *pv_return = MBE_AlbumGetAlbumType;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetAlbumName", 21)) {
    /*                            ^              */
#ifdef MBE_QuickGetAlbumName
      *pv_return = MBE_QuickGetAlbumName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'n':
    if (memEQ(name, "MBQ_FindDistinctTRMId", 21)) {
    /*                            ^              */
#ifdef MBQ_FindDistinctTRMId
      *pv_return = MBQ_FindDistinctTRMId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'r':
    if (memEQ(name, "MBE_AlbumGetTrackList", 21)) {
    /*                            ^              */
#ifdef MBE_AlbumGetTrackList
      *pv_return = MBE_AlbumGetTrackList;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_AlbumGetTrackName", 21)) {
    /*                            ^              */
#ifdef MBE_AlbumGetTrackName
      *pv_return = MBE_AlbumGetTrackName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetTrackName", 21)) {
    /*                            ^              */
#ifdef MBE_QuickGetTrackName
      *pv_return = MBE_QuickGetTrackName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetTrackName", 21)) {
    /*                            ^              */
#ifdef MBE_TrackGetTrackName
      *pv_return = MBE_TrackGetTrackName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 't':
    if (memEQ(name, "MBE_ReleaseGetCountry", 21)) {
    /*                            ^              */
#ifdef MBE_ReleaseGetCountry
      *pv_return = MBE_ReleaseGetCountry;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'u':
    if (memEQ(name, "MBE_AlbumGetNumTracks", 21)) {
    /*                            ^              */
#ifdef MBE_AlbumGetNumTracks
      *pv_return = MBE_AlbumGetNumTracks;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_22 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetAmazonAsin MBE_AlbumGetArtistName MBE_ArtistGetAlbumName
     MBE_GetRelationshipURL MBE_LookupGetRelevance MBE_QuickGetArtistName
     MBE_TrackGetArtistName MBQ_TrackInfoFromTRMId MBS_SelectLookupResult
     MBS_SelectRelationship */
  /* Offset 13 gives the best switch position.  */
  switch (name[13]) {
  case 'A':
    if (memEQ(name, "MBE_ArtistGetAlbumName", 22)) {
    /*                            ^               */
#ifdef MBE_ArtistGetAlbumName
      *pv_return = MBE_ArtistGetAlbumName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'F':
    if (memEQ(name, "MBQ_TrackInfoFromTRMId", 22)) {
    /*                            ^               */
#ifdef MBQ_TrackInfoFromTRMId
      *pv_return = MBQ_TrackInfoFromTRMId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'R':
    if (memEQ(name, "MBE_LookupGetRelevance", 22)) {
    /*                            ^               */
#ifdef MBE_LookupGetRelevance
      *pv_return = MBE_LookupGetRelevance;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'a':
    if (memEQ(name, "MBS_SelectRelationship", 22)) {
    /*                            ^               */
#ifdef MBS_SelectRelationship
      *pv_return = MBS_SelectRelationship;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBS_SelectLookupResult", 22)) {
    /*                            ^               */
#ifdef MBS_SelectLookupResult
      *pv_return = MBS_SelectLookupResult;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBE_AlbumGetAmazonAsin", 22)) {
    /*                            ^               */
#ifdef MBE_AlbumGetAmazonAsin
      *pv_return = MBE_AlbumGetAmazonAsin;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'o':
    if (memEQ(name, "MBE_GetRelationshipURL", 22)) {
    /*                            ^               */
#ifdef MBE_GetRelationshipURL
      *pv_return = MBE_GetRelationshipURL;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'r':
    if (memEQ(name, "MBE_AlbumGetArtistName", 22)) {
    /*                            ^               */
#ifdef MBE_AlbumGetArtistName
      *pv_return = MBE_AlbumGetArtistName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetArtistName", 22)) {
    /*                            ^               */
#ifdef MBE_QuickGetArtistName
      *pv_return = MBE_QuickGetArtistName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetArtistName", 22)) {
    /*                            ^               */
#ifdef MBE_TrackGetArtistName
      *pv_return = MBE_TrackGetArtistName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_23 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetAlbumStatus MBE_ArtistGetArtistName MBE_GetNumLookupResults
     MBE_GetRelationshipType */
  /* Offset 15 gives the best switch position.  */
  switch (name[15]) {
  case 'p':
    if (memEQ(name, "MBE_GetNumLookupResults", 23)) {
    /*                              ^              */
#ifdef MBE_GetNumLookupResults
      *pv_return = MBE_GetNumLookupResults;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 's':
    if (memEQ(name, "MBE_GetRelationshipType", 23)) {
    /*                              ^              */
#ifdef MBE_GetRelationshipType
      *pv_return = MBE_GetRelationshipType;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 't':
    if (memEQ(name, "MBE_ArtistGetArtistName", 23)) {
    /*                              ^              */
#ifdef MBE_ArtistGetArtistName
      *pv_return = MBE_ArtistGetArtistName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'u':
    if (memEQ(name, "MBE_AlbumGetAlbumStatus", 23)) {
    /*                              ^              */
#ifdef MBE_AlbumGetAlbumStatus
      *pv_return = MBE_AlbumGetAlbumStatus;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_25 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetAlbumArtistId MBE_AlbumGetNumCdindexIds
     MBE_AlbumGetTrackDuration MBE_QuickGetTrackDuration
     MBE_TOCGetTrackNumSectors MBE_TrackGetTrackDuration
     MBQ_GetAlbumRelationsById MBQ_GetTrackRelationsById */
  /* Offset 14 gives the best switch position.  */
  switch (name[14]) {
  case 'a':
    if (memEQ(name, "MBE_AlbumGetTrackDuration", 25)) {
    /*                             ^                 */
#ifdef MBE_AlbumGetTrackDuration
      *pv_return = MBE_AlbumGetTrackDuration;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_QuickGetTrackDuration", 25)) {
    /*                             ^                 */
#ifdef MBE_QuickGetTrackDuration
      *pv_return = MBE_QuickGetTrackDuration;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetTrackDuration", 25)) {
    /*                             ^                 */
#ifdef MBE_TrackGetTrackDuration
      *pv_return = MBE_TrackGetTrackDuration;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'b':
    if (memEQ(name, "MBE_AlbumGetAlbumArtistId", 25)) {
    /*                             ^                 */
#ifdef MBE_AlbumGetAlbumArtistId
      *pv_return = MBE_AlbumGetAlbumArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBE_TOCGetTrackNumSectors", 25)) {
    /*                             ^                 */
#ifdef MBE_TOCGetTrackNumSectors
      *pv_return = MBE_TOCGetTrackNumSectors;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'l':
    if (memEQ(name, "MBQ_GetAlbumRelationsById", 25)) {
    /*                             ^                 */
#ifdef MBQ_GetAlbumRelationsById
      *pv_return = MBQ_GetAlbumRelationsById;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBQ_GetTrackRelationsById", 25)) {
    /*                             ^                 */
#ifdef MBQ_GetTrackRelationsById
      *pv_return = MBQ_GetTrackRelationsById;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBE_AlbumGetNumCdindexIds", 25)) {
    /*                             ^                 */
#ifdef MBE_AlbumGetNumCdindexIds
      *pv_return = MBE_AlbumGetNumCdindexIds;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_26 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetArtistSortName MBE_GetRelationshipAlbumId
     MBE_GetRelationshipTrackId MBE_LookupGetAlbumArtistId
     MBE_LookupGetTrackArtistId MBE_QuickGetArtistSortName
     MBE_TrackGetArtistSortName MBQ_GetArtistRelationsById
     MBQ_GetCDInfoFromCDIndexId */
  /* Offset 8 gives the best switch position.  */
  switch (name[8]) {
  case 'D':
    if (memEQ(name, "MBQ_GetCDInfoFromCDIndexId", 26)) {
    /*                       ^                        */
#ifdef MBQ_GetCDInfoFromCDIndexId
      *pv_return = MBQ_GetCDInfoFromCDIndexId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'e':
    if (memEQ(name, "MBE_GetRelationshipAlbumId", 26)) {
    /*                       ^                        */
#ifdef MBE_GetRelationshipAlbumId
      *pv_return = MBE_GetRelationshipAlbumId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_GetRelationshipTrackId", 26)) {
    /*                       ^                        */
#ifdef MBE_GetRelationshipTrackId
      *pv_return = MBE_GetRelationshipTrackId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBE_QuickGetArtistSortName", 26)) {
    /*                       ^                        */
#ifdef MBE_QuickGetArtistSortName
      *pv_return = MBE_QuickGetArtistSortName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_TrackGetArtistSortName", 26)) {
    /*                       ^                        */
#ifdef MBE_TrackGetArtistSortName
      *pv_return = MBE_TrackGetArtistSortName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBE_AlbumGetArtistSortName", 26)) {
    /*                       ^                        */
#ifdef MBE_AlbumGetArtistSortName
      *pv_return = MBE_AlbumGetArtistSortName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'r':
    if (memEQ(name, "MBQ_GetArtistRelationsById", 26)) {
    /*                       ^                        */
#ifdef MBQ_GetArtistRelationsById
      *pv_return = MBQ_GetArtistRelationsById;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'u':
    if (memEQ(name, "MBE_LookupGetAlbumArtistId", 26)) {
    /*                       ^                        */
#ifdef MBE_LookupGetAlbumArtistId
      *pv_return = MBE_LookupGetAlbumArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    if (memEQ(name, "MBE_LookupGetTrackArtistId", 26)) {
    /*                       ^                        */
#ifdef MBE_LookupGetTrackArtistId
      *pv_return = MBE_LookupGetTrackArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_27 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_AlbumGetNumReleaseDates MBE_ArtistGetArtistSortName
     MBE_GetRelationshipArtistId MBE_TOCGetTrackSectorOffset
     MBS_SelectLookupResultAlbum MBS_SelectLookupResultTrack */
  /* Offset 26 gives the best switch position.  */
  switch (name[26]) {
  case 'd':
    if (memEQ(name, "MBE_GetRelationshipArtistI", 26)) {
    /*                                         d      */
#ifdef MBE_GetRelationshipArtistId
      *pv_return = MBE_GetRelationshipArtistId;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'e':
    if (memEQ(name, "MBE_ArtistGetArtistSortNam", 26)) {
    /*                                         e      */
#ifdef MBE_ArtistGetArtistSortName
      *pv_return = MBE_ArtistGetArtistSortName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBS_SelectLookupResultTrac", 26)) {
    /*                                         k      */
#ifdef MBS_SelectLookupResultTrack
      *pv_return = MBS_SelectLookupResultTrack;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBS_SelectLookupResultAlbu", 26)) {
    /*                                         m      */
#ifdef MBS_SelectLookupResultAlbum
      *pv_return = MBS_SelectLookupResultAlbum;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 's':
    if (memEQ(name, "MBE_AlbumGetNumReleaseDate", 26)) {
    /*                                         s      */
#ifdef MBE_AlbumGetNumReleaseDates
      *pv_return = MBE_AlbumGetNumReleaseDates;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 't':
    if (memEQ(name, "MBE_TOCGetTrackSectorOffse", 26)) {
    /*                                         t      */
#ifdef MBE_TOCGetTrackSectorOffset
      *pv_return = MBE_TOCGetTrackSectorOffset;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant_28 (pTHX_ const char *name, const char **pv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     MBE_GetRelationshipAlbumName MBE_GetRelationshipDirection
     MBE_GetRelationshipTrackName MBS_SelectLookupResultArtist */
  /* Offset 23 gives the best switch position.  */
  switch (name[23]) {
  case 'c':
    if (memEQ(name, "MBE_GetRelationshipDirection", 28)) {
    /*                                      ^           */
#ifdef MBE_GetRelationshipDirection
      *pv_return = MBE_GetRelationshipDirection;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'k':
    if (memEQ(name, "MBE_GetRelationshipTrackName", 28)) {
    /*                                      ^           */
#ifdef MBE_GetRelationshipTrackName
      *pv_return = MBE_GetRelationshipTrackName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'm':
    if (memEQ(name, "MBE_GetRelationshipAlbumName", 28)) {
    /*                                      ^           */
#ifdef MBE_GetRelationshipAlbumName
      *pv_return = MBE_GetRelationshipAlbumName;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 'r':
    if (memEQ(name, "MBS_SelectLookupResultArtist", 28)) {
    /*                                      ^           */
#ifdef MBS_SelectLookupResultArtist
      *pv_return = MBS_SelectLookupResultArtist;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant (pTHX_ const char *name, STRLEN len, const char **pv_return) {
  /* Initially switch on the length of the name.  */
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!/usr/local/bin/perl5.8.4 -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

my $types = {map {($_, 1)} qw(PV)};
my @names = (qw(MBE_AlbumGetAlbumArtistId MBE_AlbumGetAlbumId
	       MBE_AlbumGetAlbumName MBE_AlbumGetAlbumStatus
	       MBE_AlbumGetAlbumType MBE_AlbumGetAmazonAsin
	       MBE_AlbumGetArtistId MBE_AlbumGetArtistName
	       MBE_AlbumGetArtistSortName MBE_AlbumGetNumCdindexIds
	       MBE_AlbumGetNumReleaseDates MBE_AlbumGetNumTracks
	       MBE_AlbumGetTrackDuration MBE_AlbumGetTrackId
	       MBE_AlbumGetTrackList MBE_AlbumGetTrackName MBE_AlbumGetTrackNum
	       MBE_ArtistGetAlbumId MBE_ArtistGetAlbumName
	       MBE_ArtistGetArtistId MBE_ArtistGetArtistName
	       MBE_ArtistGetArtistSortName MBE_AuthGetChallenge
	       MBE_AuthGetSessionId MBE_GetError MBE_GetNumAlbums
	       MBE_GetNumArtists MBE_GetNumLookupResults MBE_GetNumTracks
	       MBE_GetNumTrmids MBE_GetRelationshipAlbumId
	       MBE_GetRelationshipAlbumName MBE_GetRelationshipArtistId
	       MBE_GetRelationshipArtistName MBE_GetRelationshipDirection
	       MBE_GetRelationshipTrackId MBE_GetRelationshipTrackName
	       MBE_GetRelationshipType MBE_GetRelationshipURL MBE_GetStatus
	       MBE_LookupGetAlbumArtistId MBE_LookupGetAlbumId
	       MBE_LookupGetArtistId MBE_LookupGetRelevance
	       MBE_LookupGetTrackArtistId MBE_LookupGetTrackId
	       MBE_LookupGetType MBE_QuerySubject MBE_QuickGetAlbumName
	       MBE_QuickGetArtistId MBE_QuickGetArtistName
	       MBE_QuickGetArtistSortName MBE_QuickGetTrackDuration
	       MBE_QuickGetTrackId MBE_QuickGetTrackName MBE_QuickGetTrackNum
	       MBE_ReleaseGetCountry MBE_ReleaseGetDate MBE_TOCGetCDIndexId
	       MBE_TOCGetFirstTrack MBE_TOCGetLastTrack
	       MBE_TOCGetTrackNumSectors MBE_TOCGetTrackSectorOffset
	       MBE_TrackGetArtistId MBE_TrackGetArtistName
	       MBE_TrackGetArtistSortName MBE_TrackGetTrackDuration
	       MBE_TrackGetTrackId MBE_TrackGetTrackName MBE_TrackGetTrackNum
	       MBI_VARIOUS_ARTIST_ID MBQ_AssociateCD MBQ_Authenticate
	       MBQ_FileInfoLookup MBQ_FindAlbumByName MBQ_FindArtistByName
	       MBQ_FindDistinctTRMId MBQ_FindTrackByName MBQ_GetAlbumById
	       MBQ_GetAlbumRelationsById MBQ_GetArtistById
	       MBQ_GetArtistRelationsById MBQ_GetCDInfo
	       MBQ_GetCDInfoFromCDIndexId MBQ_GetCDTOC MBQ_GetTrackById
	       MBQ_GetTrackByTRMId MBQ_GetTrackRelationsById
	       MBQ_QuickTrackInfoFromTrackId MBQ_SubmitTrack
	       MBQ_SubmitTrackTRMId MBQ_TrackInfoFromTRMId MBS_Back MBS_Rewind
	       MBS_SelectAlbum MBS_SelectArtist MBS_SelectCdindexid
	       MBS_SelectLookupResult MBS_SelectLookupResultAlbum
	       MBS_SelectLookupResultArtist MBS_SelectLookupResultTrack
	       MBS_SelectRelationship MBS_SelectReleaseDate MBS_SelectTrack
	       MBS_SelectTrackAlbum MBS_SelectTrackArtist MBS_SelectTrmid));

print constant_types(); # macro defs
foreach (C_constant ("MusicBrainz::Queries", 'constant', 'PV', $types, undef, 3, @names) ) {
    print $_, "\n"; # C constant subs
}
print "#### XS Section:\n";
print XS_constant ("MusicBrainz::Queries", $types);
__END__
   */

  switch (len) {
  case 8:
    if (memEQ(name, "MBS_Back", 8)) {
#ifdef MBS_Back
      *pv_return = MBS_Back;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 10:
    if (memEQ(name, "MBS_Rewind", 10)) {
#ifdef MBS_Rewind
      *pv_return = MBS_Rewind;
      return PERL_constant_ISPV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 12:
    /* Names all of length 12.  */
    /* MBE_GetError MBQ_GetCDTOC */
    /* Offset 7 gives the best switch position.  */
    switch (name[7]) {
    case 'C':
      if (memEQ(name, "MBQ_GetCDTOC", 12)) {
      /*                      ^           */
#ifdef MBQ_GetCDTOC
        *pv_return = MBQ_GetCDTOC;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    case 'E':
      if (memEQ(name, "MBE_GetError", 12)) {
      /*                      ^           */
#ifdef MBE_GetError
        *pv_return = MBE_GetError;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    }
    break;
  case 13:
    /* Names all of length 13.  */
    /* MBE_GetStatus MBQ_GetCDInfo */
    /* Offset 12 gives the best switch position.  */
    switch (name[12]) {
    case 'o':
      if (memEQ(name, "MBQ_GetCDInf", 12)) {
      /*                           o      */
#ifdef MBQ_GetCDInfo
        *pv_return = MBQ_GetCDInfo;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    case 's':
      if (memEQ(name, "MBE_GetStatu", 12)) {
      /*                           s      */
#ifdef MBE_GetStatus
        *pv_return = MBE_GetStatus;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    }
    break;
  case 15:
    return constant_15 (aTHX_ name, pv_return);
    break;
  case 16:
    return constant_16 (aTHX_ name, pv_return);
    break;
  case 17:
    return constant_17 (aTHX_ name, pv_return);
    break;
  case 18:
    /* Names all of length 18.  */
    /* MBE_ReleaseGetDate MBQ_FileInfoLookup */
    /* Offset 10 gives the best switch position.  */
    switch (name[10]) {
    case 'e':
      if (memEQ(name, "MBE_ReleaseGetDate", 18)) {
      /*                         ^              */
#ifdef MBE_ReleaseGetDate
        *pv_return = MBE_ReleaseGetDate;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    case 'f':
      if (memEQ(name, "MBQ_FileInfoLookup", 18)) {
      /*                         ^              */
#ifdef MBQ_FileInfoLookup
        *pv_return = MBQ_FileInfoLookup;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    }
    break;
  case 19:
    return constant_19 (aTHX_ name, pv_return);
    break;
  case 20:
    return constant_20 (aTHX_ name, pv_return);
    break;
  case 21:
    return constant_21 (aTHX_ name, pv_return);
    break;
  case 22:
    return constant_22 (aTHX_ name, pv_return);
    break;
  case 23:
    return constant_23 (aTHX_ name, pv_return);
    break;
  case 25:
    return constant_25 (aTHX_ name, pv_return);
    break;
  case 26:
    return constant_26 (aTHX_ name, pv_return);
    break;
  case 27:
    return constant_27 (aTHX_ name, pv_return);
    break;
  case 28:
    return constant_28 (aTHX_ name, pv_return);
    break;
  case 29:
    /* Names all of length 29.  */
    /* MBE_GetRelationshipArtistName MBQ_QuickTrackInfoFromTrackId */
    /* Offset 28 gives the best switch position.  */
    switch (name[28]) {
    case 'd':
      if (memEQ(name, "MBQ_QuickTrackInfoFromTrackI", 28)) {
      /*                                           d      */
#ifdef MBQ_QuickTrackInfoFromTrackId
        *pv_return = MBQ_QuickTrackInfoFromTrackId;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    case 'e':
      if (memEQ(name, "MBE_GetRelationshipArtistNam", 28)) {
      /*                                           e      */
#ifdef MBE_GetRelationshipArtistName
        *pv_return = MBE_GetRelationshipArtistName;
        return PERL_constant_ISPV;
#else
        return PERL_constant_NOTDEF;
#endif
      }
      break;
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

