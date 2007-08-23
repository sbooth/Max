# ------------------------------------------------------------------
#
#   libofa -- the Open Fingerprint Architecture library
#
#   Copyright (C) 2006 MusicIP Corporation
#   All rights reserved.
#
#-------------------------------------------------------------------
AUTOMAKE_OPTIONS = foreign

SUBDIRS = JAMA AFLIB

lib_LTLIBRARIES = libofa.la
INCLUDES = -I$(top_srcdir)/include

if VDSP
dist_libofa_la_SOURCES = fftlibvdsp_op.cpp fft_op.cpp frametracker_op.cpp \
        mainprint.cpp signal_op.cpp trackdata_op.cpp trackframe_op.cpp \
	tracklist_op.cpp
else
dist_libofa_la_SOURCES = fftlibw3_op.cpp fft_op.cpp frametracker_op.cpp \
	mainprint.cpp signal_op.cpp trackdata_op.cpp trackframe_op.cpp \
	tracklist_op.cpp
endif

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
libofa_la_LDFLAGS = -version-info 0:0:0 -no-undefined 
libofa_la_LIBADD = AFLIB/libaflib.la -lm 

noinst_HEADERS = error_op.h fftlib_op.h fft_op.h frametracker_op.h signal_op.h \
                 trackdata_op.h trackframe_op.h tracklist_op.h
