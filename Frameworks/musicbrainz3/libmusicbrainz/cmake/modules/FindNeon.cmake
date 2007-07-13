INCLUDE(UsePkgConfig)
PKGCONFIG(neon _NeonIncDir _NeonLinkDir _NeonLinkFlags _NeonCflags)

FIND_PATH(NEON_INCLUDE_DIR ne_request.h
    ${_NeonIncDir}
    /usr/include/neon
    /usr/local/include/neon
)

FIND_LIBRARY(NEON_LIBRARIES neon
    ${_NeonLinkDir}
    /usr/lib
    /usr/local/lib
)

IF (NEON_INCLUDE_DIR AND NEON_LIBRARIES)
    SET(NEON_FOUND TRUE)
ENDIF (NEON_INCLUDE_DIR AND NEON_LIBRARIES)

IF (NEON_FOUND)
    IF (NOT Neon_FIND_QUIETLY)
	MESSAGE(STATUS "Found Neon: ${NEON_LIBRARIES}")
    ENDIF (NOT Neon_FIND_QUIETLY)
ELSE (NEON_FOUND)
    IF (Neon_FIND_REQUIRED)
	MESSAGE(FATAL_ERROR "Could not find Neon")
    ENDIF (Neon_FIND_REQUIRED)
ENDIF (NEON_FOUND)
