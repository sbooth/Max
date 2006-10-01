#!/usr/bin/env python

import sys
import musicbrainz

def main():
    mb = musicbrainz.mb()

    print mb.GetWebSubmitURL()

if __name__ == '__main__':
    main()
