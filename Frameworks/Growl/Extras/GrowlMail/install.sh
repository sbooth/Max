#!/bin/bash
#
# install.sh - Script for installing GrowlMail.
#
# - Build GrowlMail
# - Possibly move old GrowlMail to the Trash.
# - Install new GrowlMail.
# - Enable the plugin in Mail.
# - Relaunch Mail.
#

NAME="GrowlMail"
CURDIR="`dirname $0`"
BUILD="$CURDIR/build"
SRC="$BUILD/GrowlMail.mailbundle"

BUNDLES="$HOME/Library/Mail/Bundles"
DEST="$BUNDLES/GrowlMail.mailbundle"

MV="/bin/mv"
CP="/usr/bin/ditto -v --rsrc"

UI_ECHO_PREFIX="-->"

function run ()
{
	if [[ ${VERBOSE:--NO-} == '-YES-' ]]; then
		echo "$*"
		eval $*
	else
		exec 5>&1 6>&2 1>/dev/null 2>/dev/null
		eval $*
		exec 1>&5 2>&6
	fi
}

function ui_echo ()
{
	echo $UI_ECHO_PREFIX $@
}

function stopMail ()
{
	if killall -s Mail >/dev/null 2>/dev/null; then
		ui_echo "Quitting Mail"
		run "osascript -l AppleScript -e 'quit application \"Mail\"'"
		SHOULD_RESTART_MAIL=-YES-
	fi
}

function startMail ()
{
	if [[ ${SHOULD_RESTART_MAIL:--NO-} == -YES- ]]; then
		ui_echo "Relaunching Mail"
		run "open -a Mail"
	fi
}

function cleanGrowlMail ()
{
	if [[ -e "$BUILD" ]]; then
		ui_echo "Removing old build"
		run "rm -rf \"$BUILD\""
	fi
}

function buildGrowlMail ()
{
	ui_echo "Building GrowlMail"
	run "cd \"$CURDIR\" && xcodebuild -configuration Deployment build \"SYMROOT=$BUILD\" \"OBJROOT=$BUILD\"" || exit 1
}

function installGrowlMail ()
{
	if [[ ! -d "$BUNDLES" ]]; then
		ui_echo "Creating Bundles folder"
		run "mkdir -p \"$BUNDLES\"" || exit 1
	fi

	ui_echo "Installing GrowlMail"
	run "$CP \"$SRC\" \"$DEST\"" || exit 1

	local ENABLE_BUNDLES HAS_ENABLE_BUNDLES \
		  HAS_BUNDLE_COMPATIBILITY_VERSION BUNDLE_COMPATIBILITY_VERSION
	exec 5>&1 6>&2 1>/dev/null 2>/dev/null
	ENABLE_BUNDLES=`defaults read com.apple.mail EnableBundles`
	HAS_ENABLE_BUNDLES=$?
	BUNDLE_COMPATIBILITY_VERSION=`defaults read com.apple.mail BundleCompatibilityVersion`
	HAS_BUNDLE_COMPATIBILITY_VERSION=$?
	exec 1>&5 2>&6
	
	if [[ ! ( $HAS_ENABLE_BUNDLES && $ENABLE_BUNDLES == 1 &&
			  $HAS_BUNDLE_COMPATIBILITY_VERSION && $BUNDLE_COMPATIBILITY_VERSION == 2 ) ]]; then
		ui_echo "Enabling plug-ins in Mail"
		run "defaults write com.apple.mail EnableBundles 1"
		run "defaults write com.apple.mail BundleCompatibilityVersion 2"
	fi
}

function uninstallGrowlMail ()
{
	if [[ -e "$DEST" ]]; then
		ui_echo "Moving existing GrowlMail installation to Trash"
		mkdir -p "$HOME/.Trash"		# Just in case
		local BASE HEAD INC
		BASE=`basename $DEST`
		HEAD=$BASE
		INC=0
		while [[ -e "$HOME/.Trash/$HEAD" ]]; do
			let INC=$INC+1
			HEAD=$BASE.$INC
		done
		run "$MV \"$DEST\" \"$HOME/.Trash/$HEAD\"" || exit 1
	fi
}

function usage ()
{
	cat <<-EOF
	usage: $0 [-h] [-v] action
	
	    action can be one of the following:
	        clean:      cleans up after any builds
	        build:      builds $NAME
	        install:    builds and installs $NAME
	        uninstall:  uninstalls $NAME
	EOF
	exit 1
}

while getopts vh FLAG; do
	case $FLAG in
		v)		VERBOSE=-YES-	;;
		h|\?)	usage; exit 1	;;
	esac
done

shift $(($OPTIND - 1))

if [[ $# -ne 1 ]]; then
	usage
fi

case $1 in
	clean)		cleanGrowlMail		;;
	build)		buildGrowlMail		;;
	install)	buildGrowlMail		&&
				uninstallGrowlMail	&&
				stopMail			&&
				installGrowlMail	&&
				startMail			;;
	uninstall)	uninstallGrowlMail	&&
				stopMail			&&
				startMail			;;
	*)			usage				;;
esac

exit 0
