# Makefile for installing GrowlMail
#
# - Build GrowlMail
# - Possibly move old GrowlMail to teh Trash
# - Install new GrowlMail
# - Enable the plugin in Mail.
# - Relaunch Mail.

name = GrowlMail
builddir = build
datadir = $(HOME)/Library/Mail/Bundles

CP = /usr/bin/ditto -v --rsrc

# The build style
# Possible values are Development and Deployment
BUILDSTYLE ?= Deployment

.PHONY: all $(name) clean install uninstall

install uninstall: should_restart_mail := $(shell killall -s Mail 2>/dev/null)

stopmail = $(if $(should_restart_mail),osascript -l AppleScript -e 'quit application "Mail"')

startmail = $(if $(should_restart_mail),open -a Mail)

all: $(name)

$(name):
	xcodebuild -buildstyle $(BUILDSTYLE) build "SYMROOT=$(builddir)" "OBJROOT=$(builddir)"

install: $(name)
	$(PRE_INSTALL)
	$(stopmail)
	mkdir -p "$(datadir)"
	$(CP) "$(builddir)/$<.mailbundle" "$(datadir)/$(name).mailbundle"
	defaults write com.apple.mail EnableBundles -bool YES
	defaults write com.apple.mail BundleCompatibilityVersion -int 1
	$(POST_INSTALL)
	$(startmail)

uninstall:
	$(PRE_UNINSTALL)
	$(stopmail)
	$(RM) -rf "$(datadir)/$(name).mailbundle"
	$(POST_UNINSTALL)
	$(startmail)


clean:
	xcodebuild clean "SYMROOT=$(builddir)" "OBJROOT=$(builddir)"
