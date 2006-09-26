#!/bin/sh
#
# $Id: check_cache.sh,v 1.9 2004/07/18 07:14:52 airborne Exp $

. ./settings.sh

# This script implements a set of tests to check whether the local
# CDDB cache functionality is working correctly.

# Create/clear cache
CACHE="./tmpcache"
rm -rf $CACHE > /dev/null 2>&1
mkdir $CACHE

#
# Read from cache
#
DISCID0='12345678'
DISCID1='920ef00b'
DISCID2='11111111'

# check setting of cache dir (-D option)
start_test 'Check cache dir customization'
cddb_query -c only -D $CDDB_CACHE read misc $DISCID0
check_read $? $DISCID0

# check cache dir tilde expansion
start_test 'Check cache dir ~ expansion'
HOME=$CDDB_CACHE
cddb_query -c only -D '~' read misc $DISCID0
check_read $? $DISCID0

# read from cache only (should fail because cache is empty)
start_test 'Check empty cache read'
cddb_query -c only -D $CACHE read misc $DISCID1
check_not_found $? $DISCID1

# read from server and disable cache
start_test 'Check CACHE_OFF server read (part 1)'
cddb_query -c off -D $CACHE read misc $DISCID1
check_read $? $DISCID1

# read from cache only (should still fail because previous test did not cache)
PRV_RESULT=${RESULT}
start_test 'Check CACHE_OFF cache read (part 2)'
if test ${PRV_RESULT} -eq ${FAILURE}; then
    skip 'previous test failed'
else
    cddb_query -c only -D $CACHE read misc $DISCID1
    check_not_found $? $DISCID1
fi

# read from server and enable cache
start_test 'Check CACHE_ON server read (part 1)'
cddb_query -c on -D $CACHE read misc $DISCID1
check_read $? $DISCID1

# read from cache only (should succeed because previous test filled cache)
PRV_RESULT=${RESULT}
start_test 'Check CACHE_ON cache read (part 2)'
if test ${PRV_RESULT} -eq ${FAILURE}; then
    skip 'previous test failed'
else
    cddb_query -c only -D $CACHE read misc $DISCID1
    check_read $? $DISCID1
fi

# enable cache and try to fetch non-existing disc (should fail)
start_test 'Check non-existing disc server read (part 1)'
cddb_query -c on -D $CACHE read misc $DISCID2
check_not_found $? $DISCID2

# create non-existing disc in cache and read again (should succeed now)
PRV_RESULT=${RESULT}
start_test 'Check non-existing disc cache read (part 2)'
if test ${PRV_RESULT} -eq ${FAILURE}; then
    skip 'previous test failed'
else
    cp $CACHE/misc/$DISCID1 $CACHE/misc/$DISCID2 > /dev/null 2>&1 &&
    cddb_query -c on -D $CACHE read misc $DISCID2
    check_read $? $DISCID1
fi

#
# Clean up, print results and exit accordingly
#
rm -rf $CACHE > /dev/null 2>&1
finalize
