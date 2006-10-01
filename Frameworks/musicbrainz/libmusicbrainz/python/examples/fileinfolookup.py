#!/usr/bin/env python

import musicbrainz

#so query names are shorter
q = musicbrainz

def main():
    mb = musicbrainz.mb()
    mb.SetDepth(2)
    mb.SetDebug(1)

    args = [
        '', # trmId
        '', # artistName
        '', # albumName
        '', # trackName
        '', # trackNum
        '', # duration
        '', # fileName
        '', # artistId
        '', # albumId
        '5e7d0d05-8601-43f7-a48e-9eb05a6ab445', #  trackId
    ]
    
    print "%r" % args
    try:
        mb.QueryWithArgs(q.MBQ_FileInfoLookup, args)
    except musicbrainz.MusicBrainzError:
        return 
    if mb.Select1(q.MBS_SelectLookupResult, 1):
        print "select worked"

if __name__ == '__main__':
    main()
