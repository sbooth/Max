# Get the local path to the built Growl Prefpane - for loading in the testing app.
mkdir -p $OBJROOT/include
echo "#define GROWL_OBJROOT \"$OBJROOT\"" > $SCRIPT_OUTPUT_FILE_0
