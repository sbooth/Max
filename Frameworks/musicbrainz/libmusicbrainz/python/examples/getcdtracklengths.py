#!/usr/bin/env python

import sys, os
import musicbrainz
import webbrowser

#so query names are shorter
q = musicbrainz

def main():
    mb = musicbrainz.mb()

    mb.Query(q.MBQ_GetCDTOC)

    first = mb.GetResultInt(q.MBE_TOCGetFirstTrack)
    last = mb.GetResultInt(q.MBE_TOCGetLastTrack)

    for ii in xrange(first, last + 2):
        sectors = mb.GetResultInt1(q.MBE_TOCGetTrackNumSectors, ii)
        offset = mb.GetResultInt1(q.MBE_TOCGetTrackSectorOffset, ii)
        sec = sectors / 75        
        dura = "%d:%02d" % divmod(sec, 60)
        print dura
#
# Main program starts here
#
if __name__ == "__main__":
    main()
