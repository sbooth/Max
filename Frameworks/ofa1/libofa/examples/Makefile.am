# ------------------------------------------------------------------
#
#   libofa -- the Open Fingerprint Architecture library
#
#   Copyright (C) 2006 MusicIP Corporation
#   All rights reserved.
#
#-------------------------------------------------------------------
INCLUDES = -I$(top_srcdir)/include

noinst_PROGRAMS = example

example_SOURCES = example.cpp protocol.cpp uselame.cpp wavefile.cpp protocol.h
example_LDADD = @CURL_LIBS@ @EXPAT_LIBS@ $(top_builddir)/lib/libofa.la 
