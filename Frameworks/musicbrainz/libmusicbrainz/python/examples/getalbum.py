#!/usr/bin/env python

import sys
import musicbrainz

#so query names are shorter
q = musicbrainz

def main():
    print "This program never got finished. :-("
    sys.exit(0)
    mb = musicbrainz.mb()
    mb.SetDepth(2)
    mb.SetDebug(1)
    
    mb.QueryWithArgs(q.MBQ_FindAlbumByName, [u'1'])
    print mb.GetResultRDF()
    print "no. of albums:", mb.GetResultInt(q.MBE_GetNumAlbums)
    mb.Select1(q.MBS_SelectAlbum, 1)
    for ii in range(1, mb.GetResultInt(q.MBE_AlbumGetNumTracks) + 1):
        name = mb.GetResultData1(q.MBE_AlbumGetTrackName, ii)
        dura = mb.GetResultData1(q.MBE_AlbumGetTrackDuration, ii)
        track = mb.GetResultData1(q.MBE_AlbumGetTrackNum, ii)
        
        print "track: %s %s %r" % (dura, track, name) 
        

if __name__ == '__main__':
    main()
