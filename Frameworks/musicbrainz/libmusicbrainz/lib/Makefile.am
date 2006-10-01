#
#  MusicBrainz -- The Internet music metadatabase
#
#  Copyright (C) 2000 Robert Kaye
#  
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#    $Id: Makefile.am 8443 2006-08-21 12:36:10Z luks $
#
AUTOMAKE_OPTIONS = foreign

lib_LTLIBRARIES = libmusicbrainz.la
INCLUDES = -I$(top_srcdir)/include/musicbrainz

dist_libmusicbrainz_la_SOURCES = \
  base64.c browser.c c_wrapper.cpp comhttpsocket.cpp comsocket.cpp \
  diskid.cpp haar.cpp http.cpp \
  musicbrainz.cpp sha1.c signature.cpp \
  sigxdr.cpp sigclient.cpp sigfft.cpp \
  rdfparse.c rdfextract.cpp uuid.cpp mp3.cpp
nodist_libmusicbrainz_la_SOURCES = mb.cpp

# Here are a set of rules to help you update your library version information:
#  Scheme: current:revsion:age
#  1. Start with version information of `0:0:0' for each libtool library.
#  2. Update the version information only immediately before a public release 
#     of your software. More frequent updates are unnecessary, and only 
#     guarantee that the current interface number gets larger faster.
#  3. If the library source code has changed at all since the last update, 
#     then increment revision (`c:r:a' becomes `c:r+1:a').
#  4. If any interfaces have been added, removed, or changed since the last 
#     update, increment current, and set revision to 0.
#  5. If any interfaces have been added since the last public release, then 
#     increment age.
#  6. If any interfaces have been removed since the last public release, then 
#     set age to 0. 
libmusicbrainz_la_LDFLAGS = -version-info 4:2:0 -no-undefined
libmusicbrainz_la_LIBADD = @EXPAT_LIBS@ -lstdc++ -lm

noinst_HEADERS = \
  audiosig.h base64.h comhttpsocket.h comsocket.h \
  diskid.h haar.h http.h sha1.h sigfft.h sigclient.h \
  sigcomplex.h sigxdr.h rdfparse.h rdfextract.h types.h \
  trm.h uuid.h mp3.h 
EXTRA_DIST = wincomsocket.cpp wincomsocket.h apsmetadata.h apsutility.h
