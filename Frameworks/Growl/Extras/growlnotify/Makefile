DESTDIR=/
destroot=$(DESTDIR:/=)/

DEFAULT_BUILDSTYLE=Deployment

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

all:
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) build

clean:
	xcodebuild -alltargets clean

install:
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) install DSTROOT=$(destroot)
	mkdir -p $(destroot)usr/local/share/man/man1/
	cp growlnotify.1 $(destroot)usr/local/share/man/man1/
