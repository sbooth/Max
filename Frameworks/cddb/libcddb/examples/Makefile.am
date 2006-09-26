
INCLUDES	= -I$(top_srcdir)/include -I$(top_builddir)/include $(LIBCDIO_CFLAGS)

bin_PROGRAMS = cddb_query
cddb_query_SOURCES = main.c main.h do_query.c do_read.c do_display.c \
                     cd_access.c do_sites.c do_search.c
cddb_query_LDADD = $(top_builddir)/lib/libcddb.la $(LIBICONV) $(LIBCDIO_LIBS) 
