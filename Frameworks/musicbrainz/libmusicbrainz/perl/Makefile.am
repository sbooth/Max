common_files = Changes MANIFEST MANIFEST.SKIP Makefile.PL README

fallback = fallback/const-c.inc fallback/const-xs.inc

bundle = $(common_files) Client.pm
client = $(common_files) Client.pm Client.xs ppport.h \
	 typemap \
	 t/1.t t/findalbum.t t/findartist.t t/findtrack.t t/getalbum.t \
	 t/getartist.t
queries = $(common_files) $(fallback) Queries.pm Queries.xs ppport.h t/1.t
trm = $(common_files) t/1.t TRM.pm TRM.xs

all_files = $(bundle:%=Bundle/%) $(client:%=Client/%) $(queries:%=Queries/%) \
	    $(trm:%=TRM/%)

EXTRA_DIST = $(all_files) Client/fallback/const-c.inc Client/fallback/const-xs.inc TRM/typemap
