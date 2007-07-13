INCLUDE(UsePkgConfig)
PKGCONFIG(libdiscid _DiscIdIncDir _DiscIdLinkDir _DiscIdLinkFlags _DiscIdCflags)

FIND_PATH(DISCID_INCLUDE_DIR discid/discid.h
    ${_DiscIdIncDir}
    /usr/include
    /usr/local/include
)

FIND_LIBRARY(DISCID_LIBRARIES discid
    ${_DiscIdLinkDir}
    /usr/lib
    /usr/local/lib
)

IF (DISCID_INCLUDE_DIR AND DISCID_LIBRARIES)
    SET(DISCID_FOUND TRUE)
ENDIF (DISCID_INCLUDE_DIR AND DISCID_LIBRARIES)

IF (DISCID_FOUND)
    IF (NOT DiscId_FIND_QUIETLY)
	MESSAGE(STATUS "Found DiscId: ${DISCID_LIBRARIES}")
    ENDIF (NOT DiscId_FIND_QUIETLY)
ELSE (DISCID_FOUND)
    IF (DiscId_FIND_REQUIRED)
	MESSAGE(FATAL_ERROR "Could not find DiscId")
    ENDIF (DiscId_FIND_REQUIRED)
ENDIF (DISCID_FOUND)
