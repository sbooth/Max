BUILT_SOURCES = cue_parse.h toc_parse.h
EXTRA_DIST = $(BUILT_SOURCES)
AM_YFLAGS = -d
AM_LFLAGS = -olex.yy.c
noinst_HEADERS = cd.h cdtext.h cue_parse_prefix.h toc_parse_prefix.h cuefile.h cue.h time.h toc.h
noinst_LIBRARIES = libcuefile.a
libcuefile_a_SOURCES = cd.c cdtext.c time.c cuefile.c cue_print.c toc_print.c cue_parse.y cue_scan.l toc_parse.y toc_scan.l
