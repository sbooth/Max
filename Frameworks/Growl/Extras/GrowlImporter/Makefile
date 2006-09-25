DEFAULT_BUILDSTYLE=Deployment

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

DESTDIR=/Library/Spotlight/GrowlImpoter.mdimporter

all:
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) build

install:
	rm -rf $(DESTDIR)
	cp -R build/GrowlImporter.mdimporter $(DESTDIR)
	/usr/bin/mdimport -r $(DESTDIR)

clean:
	xcodebuild -alltargets clean
