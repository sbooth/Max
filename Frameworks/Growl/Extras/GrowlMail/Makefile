# Makefile for installing GrowlMail
#
# - Build GrowlMail
# - Possibly move old GrowlMail to teh Trash
# - Install new GrowlMail
# - Enable the plugin in Mail.
# - Relaunch Mail.

name = GrowlMail
datadir = $(HOME)/Library/Mail/Bundles

CP = /usr/bin/ditto -v --rsrc
BUILD_DIR?=$(shell defaults read com.apple.Xcode PBXProductDirectory 2> /dev/null)

ifeq ($(strip $(BUILD_DIR)),)
	BUILD_DIR=build
endif

# The build style
# Possible values are Development and Deployment
BUILDCONFIGURATION?=Deployment

.PHONY: all $(name) clean install uninstall

install uninstall: should_restart_mail := $(shell killall -s Mail 2>/dev/null)

stopmail = $(if $(should_restart_mail),osascript -l AppleScript -e 'quit application "Mail"')

startmail = $(if $(should_restart_mail),open -a Mail)

all: $(name)

$(name):
	xcodebuild -configuration $(BUILDCONFIGURATION) build

install: $(name)
	$(PRE_INSTALL)
	$(stopmail)
	mkdir -p "$(datadir)"
	$(CP) "$(BUILD_DIR)/$(BUILDCONFIGURATION)/$<.mailbundle" "$(datadir)/$(name).mailbundle"
	defaults write com.apple.mail EnableBundles 1
	defaults write com.apple.mail BundleCompatibilityVersion 2
	$(POST_INSTALL)
	$(startmail)

uninstall:
	$(PRE_UNINSTALL)
	$(stopmail)
	$(RM) -rf "$(datadir)/$(name).mailbundle"
	$(POST_UNINSTALL)
	$(startmail)


clean:
	xcodebuild clean
