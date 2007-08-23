# ------------------------------------------------------------------
#
#   libofa -- the Open Fingerprint Architecture library
#
#   Copyright (C) 2006 MusicIP Corporation
#   All rights reserved.
#
#-------------------------------------------------------------------
AUTOMAKE_OPTIONS = foreign

SUBDIRS = include lib examples
DIST_SUBDIRS = include lib examples

cvsclean: distclean
	@echo "additonal cleanup for cvs commits"
	rm -f *~ *.exe
	rm -f $(PACKAGE)-$(VERSION).tar.gz

pcdir = $(libdir)/pkgconfig
pc_DATA = libofa.pc

#  README.win32 config_win32.h 
EXTRA_DIST = libofa.pc.in README COPYING

CLEANFILES = stamp-h
