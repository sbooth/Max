DEFAULT_BUILDSTYLE=Deployment

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

all:
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) build

clean:
	xcodebuild -alltargets clean

