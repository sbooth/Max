#!/bin/sh
#
# $Id: check_charset.sh,v 1.1 2004/10/16 07:56:21 airborne Exp $

. ./settings.sh

# Test parsing of some locally cached entries.  These entries are
# designed to test the parsing of all supported fields.  Mutli-line
# fields are also tested in every possible way.

DEF_ENC='UTF8'
ALT_ENC='ISO8859-1'

DISCID='12340000'

NO_ICONV_REASON='no iconv support'

#
# Check default encoding
#
start_test 'Check charset conversion (default = '$DEF_ENC')'
if test $WITH_ICONV -eq 1; then
    cddb_query -c only -D $CDDB_CACHE read misc $DISCID
    check_read $? $DISCID.$DEF_ENC
else
    skip $NO_ICONV_REASON
fi

#
# Check alternate encoding
#
start_test 'Check charset conversion (alternate = '$ALT_ENC')'
if test $WITH_ICONV -eq 1; then
    cddb_query -c only -D $CDDB_CACHE -e $ALT_ENC read misc $DISCID
    check_read $? $DISCID.$ALT_ENC
else
    skip $NO_ICONV_REASON
fi

#
# Print results and exit accordingly
#
finalize
