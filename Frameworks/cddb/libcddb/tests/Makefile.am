
# The list of available tests
check_SCRIPTS = check_discid.sh check_cache.sh check_parse.sh check_server.sh \
                check_charset.sh
check_DATA = 

EXTRA_DIST = $(check_SCRIPTS) $(check_DATA) settings.sh.in OVERVIEW.txt

dist-hook:
	mkdir $(distdir)/testcache
	mkdir $(distdir)/testcache/misc
	cp $(srcdir)/testcache/misc/1234* $(distdir)/testcache/misc/
	mkdir $(distdir)/testdata
	cp $(srcdir)/testdata/*.txt $(distdir)/testdata/

TESTS = $(check_SCRIPTS)
