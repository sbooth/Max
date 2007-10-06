dnl Process this file with autoconf to produce a configure script.
AC_INIT(src/mpc_decoder.c)
AC_CONFIG_AUX_DIR(config)
AM_INIT_AUTOMAKE(libmpcdec,1.2.6)
AM_CONFIG_HEADER(include/config.h)

AM_PROG_LIBTOOL

CFLAGS="$CFLAGS -O3 -fomit-frame-pointer -fPIC"

AC_C_BIGENDIAN(,CFLAGS="$CFLAGS -DMPC_LITTLE_ENDIAN",)

AC_HEADER_STDC
AC_HEADER_STDBOOL
AC_C_CONST
AC_C_INLINE
AC_TYPE_OFF_T
AC_TYPE_SIZE_T
AC_TYPE_INT16_T
AC_TYPE_UINT16_T
AC_TYPE_INT32_T
AC_TYPE_UINT32_T
AC_TYPE_INT64_T

if test "x$ac_cv_header_inttypes_h" = "xyes" ; then
	INTTYPES_H="#include <inttypes.h>"
else
	INTTYPES_H=""
fi

if test "x$ac_cv_c_int16_t" = "xno" ; then
        AC_MSG_ERROR([No signed 16 bit type found on this platform.])
elif test "x$ac_cv_c_int16_t" = "xyes" ; then
	ac_cv_c_int16_t=int16_t
fi

if test "x$ac_cv_c_uint16_t" = "xno" ; then
        AC_MSG_ERROR([No unsigned 16 bit type found on this platform.])
elif test "x$ac_cv_c_uint16_t" = "xyes" ; then
	ac_cv_c_uint16_t=uint16_t
fi

if test "x$ac_cv_c_int32_t" = "xno" ; then
        AC_MSG_ERROR([No signed 32 bit type found on this platform.])
elif test "x$ac_cv_c_int32_t" = "xyes" ; then
	ac_cv_c_int32_t=int32_t
fi

if test "x$ac_cv_c_uint32_t" = "xno" ; then
        AC_MSG_ERROR([No unsigned 32 bit type found on this platform.])
elif test "x$ac_cv_c_uint32_t" = "xyes" ; then
	ac_cv_c_uint32_t=uint32_t
fi

if test "x$ac_cv_c_uint64_t" = "xno" ; then
        AC_MSG_ERROR([No signed 64 bit type found on this platform.])
elif test "x$ac_cv_c_int64_t" = "xyes" ; then
	ac_cv_c_int64_t=int64_t
fi

AC_FUNC_MEMCMP
if test "x$ac_cv_func_memcmp_working" = "xno" ; then
	AC_MSG_ERROR([working memcmp is not available.])
fi

AC_CHECK_FUNCS([memmove memset], [],
        AC_MSG_ERROR([memset or memmove is missing.]))

dnl Make substitutions

AC_SUBST(VERSION)
AC_SUBST(LIBTOOL_DEPS)
AC_SUBST(INTTYPES_H)
AC_SUBST(SIZE16, $ac_cv_c_int16_t)
AC_SUBST(USIZE16, $ac_cv_c_uint16_t)
AC_SUBST(SIZE32, $ac_cv_c_int32_t)
AC_SUBST(USIZE32, $ac_cv_c_uint32_t)
AC_SUBST(SIZE64, $ac_cv_c_int64_t)
AC_SUBST(OPT)
AC_SUBST(LIBS)

AC_OUTPUT(Makefile src/Makefile include/Makefile include/mpcdec/config_types.h)
AC_MSG_RESULT([=> libmpcdec $VERSION configured successfully])
