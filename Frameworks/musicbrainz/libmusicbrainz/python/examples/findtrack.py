#!/usr/bin/env python

#TODO: fix this to do the same as findtrack.c


import sys
import musicbrainz
import difflib

#so query names are shorter
q = musicbrainz

def main():
    print "This program never got finished. :-("
    sys.exit(0)

    artist = "Violent Femmes"
    track = "Country Death Song"

    mb = musicbrainz.mb()
    
    mb.SetDepth(2)
    mb.SetDebug(1)

    artistlist = []
    albumlist = []
    
    mb.QueryWithArgs(q.MBQ_FindArtistByName, [artist])
    print mb.GetResultRDF()
    numArtists = mb.GetResultInt(q.MBE_GetNumArtists)
    if numArtists < 1:
        print "No artists found."
    for ii in range(1, numArtists+1):
        mb.Select(q.MBS_Rewind)  
        mb.Select1(q.MBS_SelectArtist, ii)  
        artistlist.append(mb.GetResultData(q.MBE_ArtistGetArtistName))
    print artistlist
    artist = difflib.get_close_matches(artist, artistlist, 1)[0]
    print artist
    
    """
    mb.QueryWithArgs(q.MBQ_FindAlbumByName, [artist, album])
    print mb.GetResultRDF()
    numAlbums = mb.GetResultInt(q.MBE_GetNumAlbums)
    if numAlbums < 1:
        print "No albums found."
    for ii in range(1, numAlbums+1):
        mb.Select(q.MBS_Rewind)  
        mb.Select1(q.MBS_SelectAlbum, ii)  
        albumlist.append(mb.GetResultData(q.MBE_AlbumGetAlbumName))
    album = difflib.get_close_matches(album, albumlist, 1)[0]
    """

    mb.QueryWithArgs(q.MBQ_FindTrackByName, [artist, '', track])
    print mb.GetResultRDF()

if __name__ == '__main__':
    main()
