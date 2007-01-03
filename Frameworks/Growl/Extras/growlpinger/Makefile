DESTDIR =

DEFAULT_BUILDSTYLE=Deployment

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

all:
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) build

clean:
	xcodebuild -alltargets clean

install: all
	install -o root -g wheel -m 0755 build/growlpinger /usr/local/bin
	install -o root -g wheel -m 0644 growlpinger.1 /usr/local/man/man1
