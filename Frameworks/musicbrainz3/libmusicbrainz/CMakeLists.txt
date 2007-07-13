PROJECT(libmusicbrainz3)
SET(PROJECT_VERSION 3.0.1)

# 1. If the library source code has changed at all since the last update, then increment revision.
# 2. If any interfaces have been added, removed, or changed since the last update, increment current, and set revision to 0.
# 3. If any interfaces have been added since the last public release, then increment age.
# 4. If any interfaces have been removed since the last public release, then set age to 0. 
SET(musicbrainz3_SOVERSION_CURRENT  6)
SET(musicbrainz3_SOVERSION_REVISION 1)
SET(musicbrainz3_SOVERSION_AGE      1)

SET(musicbrainz3_VERSION ${musicbrainz3_SOVERSION_CURRENT}.${musicbrainz3_SOVERSION_AGE}.${musicbrainz3_SOVERSION_REVISION})
SET(musicbrainz3_SOVERSION ${musicbrainz3_SOVERSION_CURRENT})

SET(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)
FIND_PACKAGE(Neon REQUIRED)
FIND_PACKAGE(CppUnit)
FIND_PACKAGE(DiscId)

SET(LIB_SUFFIX "" CACHE STRING "Define suffix of directory name (32/64)")
SET(EXEC_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX} CACHE PATH "Installation prefix for executables and object code libraries" FORCE)
SET(BIN_INSTALL_DIR ${EXEC_INSTALL_PREFIX}/bin CACHE PATH "Installation prefix for user executables" FORCE)
SET(LIB_INSTALL_DIR ${EXEC_INSTALL_PREFIX}/lib${LIB_SUFFIX} CACHE PATH  "Installation prefix for object code libraries" FORCE)
SET(INCLUDE_INSTALL_DIR ${CMAKE_INSTALL_PREFIX}/include CACHE PATH "Installation prefix for C header files" FORCE)

CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/libmusicbrainz3.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/libmusicbrainz3.pc)
CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile.cmake ${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile)
CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake ${CMAKE_CURRENT_SOURCE_DIR}/config.h)

FILE(GLOB headers ${CMAKE_CURRENT_SOURCE_DIR}/include/musicbrainz3/*.h)
INSTALL(FILES ${headers} DESTINATION ${INCLUDE_INSTALL_DIR}/musicbrainz3)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/libmusicbrainz3.pc DESTINATION ${LIB_INSTALL_DIR}/pkgconfig)

ADD_SUBDIRECTORY(src)
IF(CPPUNIT_FOUND)
    ADD_SUBDIRECTORY(test)
ENDIF(CPPUNIT_FOUND)
ADD_SUBDIRECTORY(examples)

ADD_CUSTOM_TARGET(docs
    doxygen
)

ADD_CUSTOM_TARGET(dist
    rm -rf "libmusicbrainz-${PROJECT_VERSION}"
    COMMAND svn export http://svn.musicbrainz.org/libmusicbrainz/trunk "libmusicbrainz-${PROJECT_VERSION}"
    COMMAND tar -zcvf "libmusicbrainz-${PROJECT_VERSION}.tar.gz" "libmusicbrainz-${PROJECT_VERSION}"
)
