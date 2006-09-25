DEFAULT_BUILDSTYLE=Deployment

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

DESTDIR="/Library/Automator/Show Growl Notification.action"

all:
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) build

install:
	-rm -rf $(DESTDIR)
	if [[ ! -d /Library/Automator ]]; then mkdir /Library/Automator; fi
	cp -R "build/Show Growl Notification.action" $(DESTDIR)

clean:
	xcodebuild -alltargets clean
