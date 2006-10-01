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
#    $Id: Makefile.am 781 2005-12-16 04:57:39Z robert $
#
AUTOMAKE_OPTIONS = foreign

SUBDIRS = include lib osdep examples 
DIST_SUBDIRS = osdep include lib examples perl python

cvsclean: distclean
	@echo "additonal cleanup for cvs commits"
	rm -f *~ *.exe
	rm -f mb.h cdi.cpp
	rm -f $(PACKAGE)-$(VERSION).tar.gz

pcdir = $(libdir)/pkgconfig
pc_DATA = libmusicbrainz.pc

EXTRA_DIST = libmusicbrainz.pc.in README.win32 config_win32.h \
	     mb_client.doxy mb_client.spec docs/mb_howto.txt

CLEANFILES = stamp-h
