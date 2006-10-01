# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 2' to 'tests => last_test_to_print';

use strict;
use Test::More tests => 2;
BEGIN { use_ok('MusicBrainz::Queries', qw(:all)) };


my $fail = 0;
foreach my $constname (qw(
		 MBE_AlbumGetAlbumArtistId MBE_AlbumGetAlbumId
		 MBE_AlbumGetAlbumName MBE_AlbumGetAlbumStatus
		 MBE_AlbumGetAlbumType MBE_AlbumGetAmazonAsin
		 MBE_AlbumGetArtistId
		 MBE_AlbumGetArtistName MBE_AlbumGetArtistSortName
		 MBE_AlbumGetNumCdindexIds MBE_AlbumGetNumReleaseDates
		 MBE_AlbumGetNumTracks MBE_AlbumGetTrackDuration
		 MBE_AlbumGetTrackId MBE_AlbumGetTrackList
		 MBE_AlbumGetTrackName MBE_AlbumGetTrackNum
		 MBE_ArtistGetAlbumId MBE_ArtistGetAlbumName
		 MBE_ArtistGetArtistId MBE_ArtistGetArtistName
		 MBE_ArtistGetArtistSortName MBE_AuthGetChallenge
		 MBE_AuthGetSessionId MBE_GetError MBE_GetNumAlbums
		 MBE_GetNumArtists MBE_GetNumLookupResults MBE_GetNumTracks
		 MBE_GetNumTrmids MBE_GetStatus MBE_LookupGetAlbumArtistId
		 MBE_LookupGetAlbumId MBE_LookupGetArtistId
		 MBE_LookupGetRelevance MBE_LookupGetTrackArtistId
		 MBE_LookupGetTrackId MBE_LookupGetType MBE_QuerySubject
		 MBE_QuickGetAlbumName MBE_QuickGetArtistId
		 MBE_QuickGetArtistName MBE_QuickGetArtistSortName
		 MBE_QuickGetTrackDuration MBE_QuickGetTrackId
		 MBE_QuickGetTrackName MBE_QuickGetTrackNum
		 MBE_ReleaseGetCountry MBE_ReleaseGetDate MBE_TOCGetCDIndexId
		 MBE_TOCGetFirstTrack MBE_TOCGetLastTrack
		 MBE_TOCGetTrackNumSectors MBE_TOCGetTrackSectorOffset
		 MBE_TrackGetArtistId MBE_TrackGetArtistName
		 MBE_TrackGetArtistSortName MBE_TrackGetTrackDuration
		 MBE_TrackGetTrackId MBE_TrackGetTrackName MBE_TrackGetTrackNum
		 MBE_GetRelationshipType MBE_GetRelationshipDirection MBE_GetRelationshipArtistId
  		 MBE_GetRelationshipArtistName MBE_GetRelationshipAlbumId
		 MBE_GetRelationshipAlbumName MBE_GetRelationshipTrackId
		 MBE_GetRelationshipTrackName MBE_GetRelationshipURL
		 MBI_VARIOUS_ARTIST_ID MBQ_AssociateCD MBQ_Authenticate
		 MBQ_FileInfoLookup MBQ_FindAlbumByName MBQ_FindArtistByName
		 MBQ_FindDistinctTRMId MBQ_FindTrackByName MBQ_GetAlbumById
		 MBQ_GetArtistById MBQ_GetCDInfo MBQ_GetCDInfoFromCDIndexId
		 MBQ_GetCDTOC MBQ_GetTrackById MBQ_GetTrackByTRMId
		 MBQ_QuickTrackInfoFromTrackId MBQ_SubmitTrack
		 MBQ_SubmitTrackTRMId MBQ_TrackInfoFromTRMId 
		 MBQ_GetArtistRelationsById MBQ_GetAlbumRelationsById
		 MBQ_GetTrackRelationsById MBS_Back MBS_Rewind 
		 MBS_SelectAlbum MBS_SelectArtist
		 MBS_SelectCdindexid MBS_SelectLookupResult
		 MBS_SelectLookupResultAlbum MBS_SelectLookupResultArtist
		 MBS_SelectLookupResultTrack MBS_SelectReleaseDate
		 MBS_SelectRelationship MBS_SelectTrack 
		 MBS_SelectTrackAlbum MBS_SelectTrackArtist MBS_SelectTrmid)) {
  next if (eval "my \$a = $constname; 1");
  if ($@ =~ /^Your vendor has not defined MusicBrainz::Queries macro $constname/) {
    print "# pass: $@";
  } else {
    print "# fail: $@";
    $fail = 1;
  }

}

ok( $fail == 0 , 'Constants' );
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

