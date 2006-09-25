PREFIX?=
PREFERENCEPANES_DIR=$(PREFIX)/Library/PreferencePanes
FRAMEWORKS_DIR=$(PREFIX)/Library/Frameworks
GROWL_PREFPANE=Growl.prefPane
GROWL_FRAMEWORK=Growl.framework
BUILD_DIR=build
GROWL_HELPER_APP=$(PREFERENCEPANES_DIR)/$(GROWL_PREFPANE)/Contents/Resources/GrowlHelperApp.app
HEADERDOC_DIR=Docs/HeaderDoc

#DEFAULT_BUILDSTYLE=Deployment
DEFAULT_BUILDSTYLE=Development

BUILDSTYLE?=$(DEFAULT_BUILDSTYLE)

CP=ditto --rsrc
RM=rm

.PHONY : all growl growlhelperapp growlapplicationbridge growlapplicationbridge-withinstaller frameworks clean install

all: frameworks
	xcodebuild -alltargets -buildstyle $(BUILDSTYLE) build

growl:
	xcodebuild -target Growl -buildstyle $(BUILDSTYLE) build

growlhelperapp:
	xcodebuild -target GrowlHelperApp -buildstyle $(BUILDSTYLE) build

frameworks: growlapplicationbridge growlapplicationbridge-withinstaller

growlapplicationbridge:
	xcodebuild -target Growl.framework -buildstyle $(BUILDSTYLE) build

growlapplicationbridge-withinstaller:
	xcodebuild -target Growl-WithInstaller.framework -buildstyle $(BUILDSTYLE) build

clean:
	xcodebuild -alltargets clean

install:
	killall GrowlHelperApp || true
	-$(RM) -rf $(PREFERENCEPANES_DIR)/$(GROWL_PREFPANE) $(FRAMEWORKS_DIR)/$(GROWL_FRAMEWORK)
	$(CP) $(BUILD_DIR)/$(GROWL_PREFPANE) $(PREFERENCEPANES_DIR)/$(GROWL_PREFPANE)
	open $(GROWL_HELPER_APP)

install-growl:
	killall GrowlHelperApp || true
	-$(RM) -rf $(PREFERENCEPANES_DIR)/$(GROWL_PREFPANE)
	$(CP) $(BUILD_DIR)/$(GROWL_PREFPANE) $(PREFERENCEPANES_DIR)/$(GROWL_PREFPANE)
	open $(GROWL_HELPER_APP)

headerdoc:
	rm -rf $(HEADERDOC_DIR)
	headerdoc2html -C -o $(HEADERDOC_DIR) Common/Source/GrowlDefines.h Common/Source/GrowlDefinesInternal.h Framework/Source/*.h Common/Source/GrowlPathUtil.h Display\ Plugins/GrowlDisplayProtocol.h Framework/Source/Growl.hdoc
	gatherheaderdoc $(HEADERDOC_DIR)

uninstall:
	killall GrowlHelperApp || true
	@if [ -d "/Library/PreferencePanes/Growl.prefPane" ]; then \
		echo mv "/Library/PreferencePanes/Growl.prefPane" "$(HOME)/.Trash"; \
		mv "/Library/PreferencePanes/Growl.prefPane" "$(HOME)/.Trash"; \
	elif [ -d "$(HOME)/Library/PreferencePanes/Growl.prefPane" ]; then \
		echo mv "$(HOME)/Library/PreferencePanes/Growl.prefPane" "$(HOME)/.Trash"; \
		mv "$(HOME)/Library/PreferencePanes/Growl.prefPane" "$(HOME)/.Trash"; \
	fi

	@if [ -d "/Library/Frameworks/GrowlAppBridge.framework" ]; then \
		echo mv "/Library/Frameworks/GrowlAppBridge.framework" "$(HOME)/.Trash"; \
		mv "/Library/Frameworks/GrowlAppBridge.framework" "$(HOME)/.Trash"; \
	elif [ -d "$(HOME)/Library/Frameworks/GrowlAppBridge.framework" ]; then \
		echo mv "$(HOME)/Library/Frameworks/GrowlAppBridge.framework" "$(HOME)/.Trash"; \
		mv "$(HOME)/Library/Frameworks/GrowlAppBridge.framework" "$(HOME)/.Trash"; \
	fi
