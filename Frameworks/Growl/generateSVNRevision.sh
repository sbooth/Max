#We do this so that people who launch Xcode from the UI will be able to run
#svnversion.  If we come across any other paths here where people would install
#svn by default, we should add them here.
PATH="$PATH:/opt/local/bin:/usr/local/bin:/usr/local/subversion/bin:/sw/bin"
REVISION=`svnversion .`
echo "*** Building Growl Revision: $REVISION"
mkdir -p $OBJROOT/include
#SVN_REVISION is a string because it may look like "4168M" or "4123:4168MS"
echo "#define SVN_REVISION \"$REVISION\"" > $SCRIPT_OUTPUT_FILE_0
