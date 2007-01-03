DEFAULT_BUILDSTYLE=Deployment

PREFIX?=
DESTDIR=${PREFIX}/Library/Widgets/Growl.wdgt

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

all:
	make -C GrowlWidgetPlugin all

install:
	rm -rf $(DESTDIR)
	mkdir -p $(DESTDIR)
	cp -f *.png GrowlWidget.* *.plist $(DESTDIR)
	cp -R GrowlWidgetPlugin/build/GrowlWidgetPlugin.widgetplugin $(DESTDIR)
	/Developer/Tools/SetFile -a E $(DESTDIR)

clean:
	make -C GrowlWidgetPlugin clean
