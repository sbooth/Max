#!/bin/sh
#
# $Id: check_server.sh,v 1.8 2005/07/23 09:43:17 airborne Exp $

. ./settings.sh

# This script implements a set of tests to check whether the CDDB
# server access functionality is working correctly.  It tests all
# three protocols: CDDBP, HTTP and HTTP via a proxy.  We set the local
# cache dir to the directory with the test data to make sure we do not
# read the requested entries from the cache.

# Check whether we have proxy settings
if test -z "$http_proxy"; then
    NO_PROXY=1
    NO_PROXY_REASON='$http_proxy not defined'
else 
    NO_PROXY=0
fi

#
# Query disc with single match
#
QUERY_DATA='2259 8 155 25947 47357 66630 91222 110355 124755 148317'

start_test 'CDDBP disc query (single match)'
cddb_query -c off -D $CDDB_CACHE -P cddbp query $QUERY_DATA
check_query $?

start_test 'HTTP  disc query (single match)'
cddb_query -c off -D $CDDB_CACHE -P http  query $QUERY_DATA
check_query $?

start_test 'PROXY disc query (single match)'
if test $NO_PROXY -eq 1; then
    skip $NO_PROXY_REASON
else
    cddb_query -c off -D $CDDB_CACHE -P proxy query $QUERY_DATA
    check_query $?
fi

#
# Query disc with multiple matches
#
QUERY_DATA='3822 11 150 28690 51102 75910 102682 121522 149040 175772 204387 231145 268065'

start_test 'CDDBP disc query (multiple matches)'
cddb_query -c off -D $CDDB_CACHE -P cddbp query $QUERY_DATA
check_query $?

start_test 'HTTP  disc query (multiple matches)'
cddb_query -c off -D $CDDB_CACHE -P http  query $QUERY_DATA
check_query $?

start_test 'PROXY disc query (multiple matches)'
if test $NO_PROXY -eq 1; then
    skip $NO_PROXY_REASON
else
    cddb_query -c off -D $CDDB_CACHE -P proxy query $QUERY_DATA
    check_query $?
fi

#
# Search string (multiple matches)
#
SEARCH_DATA='mezzanine'

start_test 'HTTP  text search (multiple matches)'
cddb_query search $SEARCH_DATA
check_query $?

#
# Read disc data from server
#
DISCID='920ef00b'

start_test 'CDDBP disc read '${DISCID}
cddb_query -c off -D $CDDB_CACHE -P cddbp read misc $DISCID
check_read $? $DISCID

start_test 'HTTP  disc read '${DISCID}
cddb_query -c off -D $CDDB_CACHE -P http  read misc $DISCID
check_read $? $DISCID

start_test 'PROXY disc read '${DISCID}
if test $NO_PROXY -eq 1; then
    skip $NO_PROXY_REASON
else
    cddb_query -c off -D $CDDB_CACHE -P proxy read misc $DISCID
    check_read $? $DISCID
fi

#
# Print results and exit accordingly
#
finalize
