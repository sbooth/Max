DEFAULT_BUILDCONFIGURATION=Deployment

BUILDCONFIGURATION?=$(DEFAULT_BUILDCONFIGURATION)

all:
	xcodebuild -alltargets -configuration $(BUILDCONFIGURATION) build

clean:
	xcodebuild -alltargets clean
