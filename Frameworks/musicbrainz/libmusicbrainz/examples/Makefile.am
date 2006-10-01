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
#    $Id: Makefile.am 751 2005-10-27 00:23:32Z robert $
#

INCLUDES = -I$(top_srcdir)/include

noinst_PROGRAMS = cpp_example findartist findalbum findtrack gettrack cdlookup gettrm submittrm getalbum getartist mp3info getrels

cpp_example_SOURCES = cpp_example.cpp
cpp_example_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

findartist_SOURCES = findartist.c
findartist_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

findalbum_SOURCES = findalbum.c
findalbum_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

findtrack_SOURCES = findtrack.c
findtrack_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

gettrack_SOURCES = gettrack.c
gettrack_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

gettrm_SOURCES = gettrm.c
gettrm_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

cdlookup_SOURCES = cdlookup.c
cdlookup_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

submittrm_SOURCES = submittrm.c
submittrm_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

getalbum_SOURCES = getalbum.c
getalbum_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

getrels_SOURCES = getrels.c
getrels_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

getartist_SOURCES = getartist.c
getartist_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

mp3info_SOURCES = mp3info.c
mp3info_LDADD = $(top_builddir)/lib/libmusicbrainz.la -lstdc++ -lm

EXTRA_DIST = win32/examples.dsp win32/cmd.dsp win32/examples.opt
