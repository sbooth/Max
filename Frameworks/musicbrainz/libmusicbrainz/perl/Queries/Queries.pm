package MusicBrainz::Queries;

# $Id: Queries.pm 8095 2006-07-04 19:45:43Z svanzoest $

use 5.006_001; 
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use MusicBrainz::Queries ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	MBE_AlbumGetAlbumArtistId
	MBE_AlbumGetAlbumArtistName
	MBE_AlbumGetAlbumArtistSortName
	MBE_AlbumGetAlbumId
	MBE_AlbumGetAlbumName
	MBE_AlbumGetAlbumStatus
	MBE_AlbumGetAlbumType
	MBE_AlbumGetAmazonAsin
	MBE_AlbumGetArtistId
	MBE_AlbumGetArtistName
	MBE_AlbumGetArtistSortName
	MBE_AlbumGetCdindexId
	MBE_AlbumGetNumCdindexIds
	MBE_AlbumGetNumReleaseDates
	MBE_AlbumGetNumTracks
	MBE_AlbumGetTrackDuration
	MBE_AlbumGetTrackId
	MBE_AlbumGetTrackList
	MBE_AlbumGetTrackName
	MBE_AlbumGetTrackNum
	MBE_ArtistGetAlbumId
	MBE_ArtistGetAlbumName
	MBE_ArtistGetArtistId
	MBE_ArtistGetArtistName
	MBE_ArtistGetArtistSortName
	MBE_AuthGetChallenge
	MBE_AuthGetSessionId
	MBE_GetError
	MBE_GetNumAlbums
	MBE_GetNumArtists
	MBE_GetNumLookupResults
	MBE_GetNumTracks
	MBE_GetNumTrmids
	MBE_GetStatus
	MBE_LookupGetAlbumArtistId
	MBE_LookupGetAlbumId
	MBE_LookupGetArtistId
	MBE_LookupGetRelevance
	MBE_LookupGetTrackArtistId
	MBE_LookupGetTrackId
	MBE_LookupGetType
	MBE_QuerySubject
	MBE_QuickGetAlbumName
	MBE_QuickGetArtistId
	MBE_QuickGetArtistName
	MBE_QuickGetArtistSortName
	MBE_QuickGetTrackDuration
	MBE_QuickGetTrackId
	MBE_QuickGetTrackName
	MBE_QuickGetTrackNum
	MBE_ReleaseGetCountry
	MBE_ReleaseGetDate
	MBE_TOCGetCDIndexId
	MBE_TOCGetFirstTrack
	MBE_TOCGetLastTrack
	MBE_TOCGetTrackNumSectors
	MBE_TOCGetTrackSectorOffset
	MBE_TrackGetArtistId
	MBE_TrackGetArtistName
	MBE_TrackGetArtistSortName
	MBE_TrackGetTrackDuration
	MBE_TrackGetTrackId
	MBE_TrackGetTrackName
	MBE_TrackGetTrackNum
	MBE_GetRelationshipType
	MBE_GetRelationshipDirection
	MBE_GetRelationshipArtistId
	MBE_GetRelationshipArtistName
	MBE_GetRelationshipAlbumId
	MBE_GetRelationshipAlbumName
	MBE_GetRelationshipAttribute
	MBE_GetRelationshipTrackId
	MBE_GetRelationshipTrackName
	MBE_GetRelationshipURL
	MBI_VARIOUS_ARTIST_ID
	MBQ_AssociateCD
	MBQ_Authenticate
	MBQ_FileInfoLookup
	MBQ_FindAlbumByName
	MBQ_FindArtistByName
	MBQ_FindDistinctTRMId
	MBQ_FindTrackByName
	MBQ_GetAlbumById
	MBQ_GetArtistById
	MBQ_GetCDInfo
	MBQ_GetCDInfoFromCDIndexId
	MBQ_GetCDTOC
	MBQ_GetTrackById
	MBQ_GetTrackByTRMId
	MBQ_QuickTrackInfoFromTrackId
	MBQ_SubmitTrack
	MBQ_SubmitTrackTRMId
	MBQ_TrackInfoFromTRMId
	MBQ_GetArtistRelationsById
	MBQ_GetAlbumRelationsById
	MBQ_GetTrackRelationsById
	MBS_Back
	MBS_Rewind
	MBS_SelectAlbum
	MBS_SelectAlbumArtist
	MBS_SelectArtist
	MBS_SelectRelationship
	MBS_SelectCdindexid
	MBS_SelectLookupResult
	MBS_SelectLookupResultAlbum
	MBS_SelectLookupResultArtist
	MBS_SelectLookupResultTrack
	MBS_SelectReleaseDate
	MBS_SelectTrack
	MBS_SelectTrackAlbum
	MBS_SelectTrackArtist
	MBS_SelectTrmid
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.11';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&MusicBrainz::Queries::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('MusicBrainz::Queries', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

MusicBrainz::Queries - MusicBrainz RDF Query Constants

=head1 SYNOPSIS

  use MusicBrainz::Queries qw(:all);

=head1 DESCRIPTION

This module is used to provide access to the RDF Query Constants
used by the MusicBrainz::Client module for querying the MusicBrainz
server.

=head2 EXPORT

None by default.

=head2 Exportable constants

=over

=item MBE_AlbumGetAlbumArtistId

Return the Artist ID of the currently selected Album. This may return the artist 
id for the Various Artists' artist, and then you should check the artist for
each track of the album seperately with MBE_AlbumGetArtistName, 
MBE_AlbumGetArtistSortName and MBE_AlbumGetArtistId.

=item MBE_AlbumGetAlbumArtistName

Return the name of the artist for this album.

=item MBE_AlbumGetAlbumArtistSortName

Return the sortname of the artist for this album. 
	
=item  MBE_AlbumGetAlbumId

Return the ID of the currently selected Album.

=item  MBE_AlbumGetAlbumName

Return the name of the currently selected Album.

=item  MBE_AlbumGetAlbumStatus
 
Return the release status of the currently selected Album.

=item MBE_AlbumGetAlbumType

Return the release type of the currently selected Album.

=item MBE_AlbumGetAmazonAsin

Return the Amazon.com ASIN for the currently selected Album.

=item MBE_AlbumGetArtistId

Return the artist Id of the nth track in the album. Requires a 
track index ordinal. 1 for the first track, etc...

=item  MBE_AlbumGetArtistName

Return the artist name of the nth track in the album. Requires 
a track index ordinal. 1 for the first track, etc...

=item  MBE_AlbumGetArtistSortName

Return the artist sortname of the nth track in the album. 
Requires a track index ordinal. 1 for the first track, etc...

=item  MBE_AlbumGetCdindexId

Return the nth cdindex of the album. Requires a index 
ordinal. 1 for the first cdindex, etc... 

=item  MBE_AlbumGetNumCdindexIds

Return the number of cdindexds returned in this query.

=item  MBE_AlbumGetNumReleaseDates

Return the number of release dates for the currently selected Album

=item  MBE_AlbumGetNumTracks

Return the mumber of tracks in the currently selected Album

=item  MBE_AlbumGetTrackDuration

Return the track duration of the nth track in the album. 
Requires a track index ordinal. 1 for the first track, etc...

=item  MBE_AlbumGetTrackId

Return the Id of the nth track in the album. Requires a 
track index ordinal. 1 for the first track, etc...

=item  MBE_AlbumGetTrackList

Return the track list of an album. This extractor should 
only be used to specify a list for get_ordinal_from_list().

=item  MBE_AlbumGetTrackName

Return the track name of the nth track in the album. 
Requires a track index ordinal. 1 for the first track, etc...

=item  MBE_AlbumGetTrackNum

Return the track number of the nth track in the album. 
Requires a track index ordinal. 1 for the first track, etc...

=item  MBE_ArtistGetAlbumId

Return the ID of the nth album. Requires an ordinal 
argument to select an album from a list of albums in 
the current artist.

=item  MBE_ArtistGetAlbumName

Return the name of the nth album. Requires an ordinal 
argument to select an album from a list of albums in 
the current artist.

=item  MBE_ArtistGetArtistId

Return the ID of the currently selected Album.

=item  MBE_ArtistGetArtistName

Return the name of the currently selected Album

=item  MBE_ArtistGetArtistSortName

Return the sort name of the currently selected Album

=item  MBE_AuthGetChallenge

Return the Auth Challenge data from the Auth Query 
This query will be used internally by the client library.

=item  MBE_AuthGetSessionId

Return the Session Id from the Auth Query. This query 
will be used internally by the client library.

=item  MBE_GetError

Internal use only.

=item  MBE_GetNumAlbums

Return the number of albums returned in this query.

=item  MBE_GetNumArtists

Return the number of artist returned in this query.

=item  MBE_GetNumLookupResults

Return the number of lookup results returned in this query.

=item  MBE_GetNumTracks

Return the number of tracks returned in this query.

=item  MBE_GetNumTrmids

Return the number of trmids returned in this query.

=item  MBE_GetStatus

Get the general return status of this query. 
Values for this include OK or fuzzy. Fuzzy is 
returned when the server made a fuzzy match 
somewhere while handling the query. 

=item  MBE_LookupGetAlbumArtistId

Return the artist id associated with the album of the lookup result.

=item  MBE_LookupGetAlbumId

Return the album id of the lookup result.

=item  MBE_LookupGetArtistId

Return the artist id of the lookup result.

=item  MBE_LookupGetRelevance

Return the relevance of the lookup result.

=item  MBE_LookupGetTrackArtistId

Return the artist id associated with the track of the lookup result.

=item  MBE_LookupGetTrackId

Return the track id of the lookup result.

=item  MBE_LookupGetType

Return the type of the lookup result.

=item  MBE_QuerySubject

Internal use only.

=item  MBE_QuickGetAlbumName

Return the name of the album.

=item  MBE_QuickGetArtistId

Return the id of the artist.

=item  MBE_QuickGetArtistName

Return the name of the artist.

=item  MBE_QuickGetArtistSortName

Return the sort name of the artist.

=item  MBE_QuickGetTrackDuration

Return the track duration.

=item  MBE_QuickGetTrackId

Return the MB track id.

=item  MBE_QuickGetTrackName

Return the name of the track.

=item  MBE_QuickGetTrackNum

Return the number of the track.

=item  MBE_ReleaseGetCountry

Return the country in which the album was released

=item  MBE_ReleaseGetDate

Return the date the album was released

=item  MBE_TOCGetCDIndexId

Return the CDIndex ID from the table of contents from the CD.

=item  MBE_TOCGetFirstTrack

Return the first track number from the table of contents from the CD.

=item  MBE_TOCGetLastTrack

Return the last track number (total number of tracks on the CD) 
from the table of contents from the CD.

=item  MBE_TOCGetTrackNumSectors

Return the number of sectors for the nth track. One ordinal 
argument must be given to specify the track. Track 1 is a 
special lead-out track, and the actual track 1 on a CD can 
be retrieved as track 2 and so forth.

=item  MBE_TOCGetTrackSectorOffset

Return the sector offset from the nth track. One ordinal 
argument must be given to specify the track. Track 1 is a 
special lead-out track, and the actual track 1 on a CD can 
be retrieved as track 2 and so forth.

=item  MBE_TrackGetArtistId

Return the Id of the artist for this track.

=item  MBE_TrackGetArtistName

Return the name of the artist for this track.

=item  MBE_TrackGetArtistSortName

Return the sortname of the artist for this track.

=item  MBE_TrackGetTrackDuration

Return the track duration in the currently selected track.

=item  MBE_TrackGetTrackId

Return the ID of the currently selected track.

=item  MBE_TrackGetTrackName

Return the name of the currently selected track.

=item  MBE_TrackGetTrackNum

Return the track number in the currently selected track.

=item  MBE_GetRelationshipType

Get the type of an advanced relationships ilnk. Pleaes note that
these relatnship types can change over time!

=item  MBE_GetRelationshipDirection

Get the direction of a link between two like entities. This
data element will only be present for links between like types
(eg artist-artist links) and IFF the link direction is reversed of what the
RDF implies.

=item  MBE_GetRelationshipArtistId

Get the artist id that this link points to.

=item  MBE_GetRelationshipArtistName

Get the artist name that this link points to.

=item  MBE_GetRelationshipAlbumId

Get the album id that this link points to.

=item  MBE_GetRelationshipAlbumName

Get the album name that this link points to.

=item  MBE_GetRelationshipAttribute

Get the vocal/instrument attributes. Must pass an ordinal to indicate which attribute to get. 

=item  MBE_GetRelationshipTrackId

Get the track id that this link points to.

=item  MBE_GetRelationshipTrackName

Get the track name that this link points to.

=item  MBE_GetRelationshipURL

Get the URL that this link points to.

=item  MBI_VARIOUS_ARTIST_ID

The MusicBrainz artist id used to indicate that an 
album is a various artist album.

=item  MBQ_AssociateCD

Internal use only. 

=item  MBQ_Authenticate

This query is use to start an authenticated 
session with the MB server. The username is sent 
to the server, and the server responds with session 
id and a challenge sequence that the client needs to 
use to create a session key. The session key and
session id need to be provided with the MBQ_SubmitXXXX 
functions in order to give moderators/users credit 
for their submissions. This query will be carried out 
by the client libary automatically -- you should 
not need to use it.

=item  MBQ_FileInfoLookup

Lookup metadata for one file. This function can be 
used by tagging applications to attempt to match a 
given track with a track in the database. The server 
will attempt to match an artist, album and track 
during three phases. If at any one lookup phase the 
server finds ONE item only, it will move on to to 
the next phase. If no items are returned, an error
message is returned. If more then one item is returned, 
the end-user will have to choose one from the returned 
list and then make another call to the server. To 
express the choice made by a user, the client should 
leave the artistName/albumName empty and provide the 
artistId and/or albumId empty on the subsequent call. 
Once an artistId or albumId is provided the server will 
pick up from the given Ids and attempt to resolve the 
next phase.

=item  MBQ_FindAlbumByName

Use this query to find albums by name. This function 
returns an albumList for the given album name.

=item  MBQ_FindArtistByName

Use this query to find artists by name. This function 
returns an artistList for the given artist name.

=item  MBQ_FindDistinctTRMId

Use this function to find TRM Ids that match a given 
artistName and trackName, This query returns a trmidList.

=item  MBQ_FindTrackByName

Use this query to find tracks by name. This function 
returns a trackList for the given track name.

=item  MBQ_GetAlbumById

Retrieve an albumList from a given Album id.

=item  MBQ_GetArtistById

Retrieve an artistList from a given Artist id.

=item  MBQ_GetCDInfo

Use this query to look up a CD from MusicBrainz. 
This query will examine the CD-ROM in the CD-ROM 
drive specified by set_device() and then send 
the CD-ROM data to the server. The server will 
then find any matching CDs and return then as 
an albumList.

=item  MBQ_GetCDInfoFromCDIndexId

Use this query to return an albumList for 
the given CD Index Id.

=item  MBQ_GetCDTOC

Use this query to examine the table of contents 
of a CD. This query will examine the CD-ROM in 
the CD-ROM drive specified by set_device(), and 
then let the use extract data from the table of 
contents using the MBQ_TOCXXXXX functions. No 
live net connection is required for this query. 

=item  MBQ_GetTrackById

Retrieve an trackList from a given Track id.

=item  MBQ_GetTrackByTRMId

Retrieve an trackList from a given TRM Id.

=item  MBQ_QuickTrackInfoFromTrackId

Use this query to return the basic metadata 
information (artistname, albumname, 
trackname, tracknumber) for a given track mb id.

=item  MBQ_SubmitTrack

Internal use only.

=item  MBQ_SubmitTrackTRMId

Submit a single TrackId, TRM Id pair to 
MusicBrainz. This query can handle only one 
pair at a time, which is inefficient. The 
user may wish to create the query RDF text by 
hand and provide more than one pair in the 
rdf:Bag, since the server can handle up 
to 1000 pairs in one query.

=item  MBQ_TrackInfoFromTRMId

Use this query to return the metadata 
information (artistname, albumname, 
trackname, tracknumber) for a given trm id. 
Optionally, you can also specifiy the basic 
artist metadata, so that if the server 
cannot match on the TRM id, it will attempt 
to match based on the basic metadata. 
In case of a TRM collision (where one TRM 
may point to more than one track) this 
function will return more than on track. 
The user (or tagging app) must decide 
which track information is correct.

=item  MBQ_GetArtistRelationsById

Retrieve an artistList with advanced relationships from a given artist id

=item  MBQ_GetAlbumRelationsById

Retrieve an albumList with advanced relationships from a given album id

=item  MBQ_GetTrackRelationsById

Retrieve a trackList with advanced relationships from a give track id

=item  MBS_Back

Use this query to change the current 
context back one level.

=item  MBS_Rewind

Use this query to reset the current 
context back to the top level of the response.

=item  MBS_SelectAlbum

Use this Select Query to select an album from 
an query that returns a list of albums. Giving 
the argument 1 for the ordinal selects the 
first album in the list, 2 the second and 
so on. Use MBE_AlbumXXXXXX queries to 
extract data after the select.

=item  MBS_SelectArtist

Use this Select Query to select an artist from 
an query that returns a list of artists. Giving 
the argument 1 for the ordinal selects the 
first artist in the list, 2 the second and so 
on. Use MBE_ArtistXXXXXX queries to extract 
data after the select.

=item  MBS_SelectCdindexid

Use this Select Query to select a CD Index id 
from the list.

=item  MBS_SelectLookupResult

Use this Select Query to select a result from 
a lookupResultList. This select will be used 
in conjunction with MBQ_FileLookup.

=item  MBS_SelectLookupResultAlbum

Use this Select Query to select the album 
from a lookup result. This select will be 
used in conjunction with MBQ_FileLookup.

=item  MBS_SelectLookupResultArtist

Use this Select Query to select the artist 
from a lookup result. This select will be 
used in conjunction with MBQ_FileLookup.

=item  MBS_SelectLookupResultTrack

Use this Select Query to select the track 
from a lookup result. This select will be 
used in conjunction with MBQ_FileLookup.

=item  MBS_SelectReleaseDate

Use this Select Query to select a Release 
date/country from the list.

=item  MBS_SelectTrack

Use this Select Query to select a track 
from an query that returns a list of 
tracks. Giving the argument 1 for the 
ordinal selects the first track in the 
list, 2 the second and so on. Use 
MBE_TrackXXXXXX queries to extract 
data after the select.

=item  MBS_SelectTrackAlbum

Use this Select Query to select an 
the corresponding artist from a 
track context. MBE_ArtistXXXXXX 
queries to extract data after the select.

=item  MBS_SelectTrackArtist

Use this Select Query to select an the 
corresponding artist from a track 
context. MBE_ArtistXXXXXX queries to 
extract data after the select.

=item  MBS_SelectTrmid

Use this Select Query to select a 
trmid from the list.

=item  MBS_SelectRelationship

Use this Select Query to select a relationship from a list 
advanced relationships. 

=item MBS_SelectAlbumArtist

Use this Select Query to select an the corresponding artist from an album  
context. MBE_ArtistXXXXXX queries to extract data after the select. 
	
=back


=head1 SEE ALSO

MusicBrainz::Client

http://www.musicbrainz.org/docs/mb_client/queries_8h.html

=head1 AUTHOR

Sander van Zoest, E<lt>svanzoest@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2006 by Alexander van Zoest

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
