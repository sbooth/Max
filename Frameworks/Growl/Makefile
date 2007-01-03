PREFIX?=
PREFERENCEPANES_DIR=$(PREFIX)/Library/PreferencePanes
FRAMEWORKS_DIR=$(PREFIX)/Library/Frameworks
GROWL_PREFPANE=Growl.prefPane
GROWL_FRAMEWORK=Growl.framework
BUILD_DIR=build
GROWL_HELPER_APP=$(PREFERENCEPANES_DIR)/$(GROWL_PREFPANE)/Contents/Resources/GrowlHelperApp.app
HEADERDOC_DIR=Docs/HeaderDoc

#DEFAULT_CONFIGURATION=Deployment
DEFAULT_CONFIGURATION=Development

CONFIGURATION?=$(DEFAULT_CONFIGURATION)

CP=ditto --rsrc
RM=rm

.PHONY : all growl growlhelperapp growlapplicationbridge growlapplicationbridge-withinstaller frameworks clean install localizable-strings

all: frameworks
	xcodebuild -alltargets -configuration $(CONFIGURATION) build

growl:
	xcodebuild -target Growl -configuration $(CONFIGURATION) build

growlhelperapp:
	xcodebuild -target GrowlHelperApp -configuration $(CONFIGURATION) build

frameworks: growlapplicationbridge growlapplicationbridge-withinstaller

growlapplicationbridge:
	xcodebuild -target Growl.framework -configuration $(CONFIGURATION) build

growlapplicationbridge-withinstaller:
	xcodebuild -target Growl-WithInstaller.framework -configuration $(CONFIGURATION) build

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

localizable-strings:
	genstrings -o Core/Resources/English.lproj Core/Source/*.h Core/Source/*.m
	genstrings -o Display\ Plugins/Bezel/English.lproj Display\ Plugins/Bezel/*.h Display\ Plugins/Bezel/*.m
	genstrings -o Display\ Plugins/Brushed/English.lproj Display\ Plugins/Brushed/*.h Display\ Plugins/Brushed/*.m
	genstrings -o Display\ Plugins/Bubbles/English.lproj Display\ Plugins/Bubbles/*.h Display\ Plugins/Bubbles/*.m
	genstrings -o Display\ Plugins/Log/English.lproj Display\ Plugins/Log/*.h Display\ Plugins/Log/*.m
	genstrings -o Display\ Plugins/MailMe/English.lproj Display\ Plugins/MailMe/*.h Display\ Plugins/MailMe/*.m
	genstrings -o Display\ Plugins/MusicVideo/English.lproj Display\ Plugins/MusicVideo/*.h Display\ Plugins/MusicVideo/*.m
	genstrings -o Display\ Plugins/Smoke/English.lproj Display\ Plugins/Smoke/*.h Display\ Plugins/Smoke/*.m
	genstrings -o Display\ Plugins/Speech/English.lproj Display\ Plugins/Speech/*.h Display\ Plugins/Speech/*.m
	genstrings -o Display\ Plugins/WebKit/English.lproj Display\ Plugins/WebKit/*.h Display\ Plugins/WebKit/*.m
	genstrings -o Framework/Resources/English.lproj Framework/Source/*.h Framework/Source/*.m Framework/Source/*.c
