CC=gcc
CPPFLAGS=-F../../build
CFLAGS=-W -Wall
LDFLAGS=-F../../build -framework CoreFoundation -framework Growl

all: bundle

BUNDLE_NAME=GrowlCarbon.app

bundle: growl-carbon
	mkdir $(BUNDLE_NAME)
	mkdir $(BUNDLE_NAME)/Contents
	mkdir $(BUNDLE_NAME)/Contents/MacOS
	mkdir $(BUNDLE_NAME)/Contents/Resources
	mkdir $(BUNDLE_NAME)/Contents/Frameworks
	echo "APPL????" > $(BUNDLE_NAME)/Contents/PkgInfo
	cp growl-carbon $(BUNDLE_NAME)/Contents/MacOS
	cp Info.plist $(BUNDLE_NAME)/Contents
	cp -r ../../build/Growl.framework $(BUNDLE_NAME)/Contents/Frameworks

growl-carbon: growl-carbon.o

clean:
	rm -rf $(BUNDLE_NAME)
	rm -f *~ *.o growl-carbon
