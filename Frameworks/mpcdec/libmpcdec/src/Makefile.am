## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = foreign

lib_LTLIBRARIES = libmpcdec.la

libmpcdec_la_SOURCES = \
	huffsv46.c \
	huffsv7.c \
	idtag.c \
	mpc_decoder.c \
	mpc_reader.c \
	requant.c \
	streaminfo.c \
	synth_filter.c
libmpcdec_la_LDFLAGS = -no-undefined -version-info 5:2:0

noinst_PROGRAMS = sample
sample_SOURCES = sample.cpp
sample_LDADD = libmpcdec.la
sample_LDFLAGS = -static

INCLUDES = -I$(top_srcdir)/include -I$(top_srcdir)/src
