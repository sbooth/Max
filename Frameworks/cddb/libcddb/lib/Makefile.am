
INCLUDES	= -I$(top_srcdir)/include -I$(top_builddir)/include

lib_LTLIBRARIES = libcddb.la
libcddb_la_SOURCES = cddb_track.c cddb_disc.c cddb_regex.c cddb_error.c \
					 cddb_conn.c cddb_cmd.c cddb_net.c cddb_log.c cddb_util.c \
					 cddb.c cddb_site.c ll.c
libcddb_la_LDFLAGS = -no-undefined -version-info 3:1:1 $(LIBICONV)
