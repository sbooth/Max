
SUBDIRS	= include lib examples tests
EXTRA_DIST = doc/doxygen.conf misc/$(PACKAGE).ebuild

dist-hook:
	cp $(top_srcdir)/misc/$(PACKAGE).ebuild $(distdir)/misc/$(PACKAGE)-$(VERSION).ebuild

# pkg-config(1) related rules
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libcddb.pc
$(pkgconfig_DATA): config.status
