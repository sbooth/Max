prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=${EXEC_INSTALL_PREFIX}
libdir=${LIB_INSTALL_DIR}
includedir=${INCLUDE_INSTALL_DIR}

Name: ${PROJECT_NAME}
Description: The Musicbrainz Client Library.
URL: http://musicbrainz.org/doc/libmusicbrainz
Version: ${PROJECT_VERSION}
Requires: neon >= 0.25, libdiscid
Libs: -L${LIB_INSTALL_DIR} -lmusicbrainz3
Cflags: -I${INCLUDE_INSTALL_DIR}

