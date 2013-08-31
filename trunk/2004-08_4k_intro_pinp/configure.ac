AC_INIT([piNp], [1.0.0], [trilkk@gmail.com])

AC_CANONICAL_BUILD
AC_CANONICAL_HOST
AC_CANONICAL_TARGET

AM_INIT_AUTOMAKE([dist-bzip2])

AC_CHECK_C99
AC_CHECK_CXX

AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_C_BIGENDIAN

AC_COMPILE_MODE([MODE_DEBUG])

AC_CONDITIONAL_DEFINE([USE_LD], [yes])

AC_CHECK_HEADER([inttypes.h])
AC_CHECK_HEADER([stdint.h])

AC_INCORPORATE_OPENGL([PINP_OPENGL], [yes])
AC_INCORPORATE_GLUT([PINP_GLUT], [yes])
AC_INCORPORATE_SDL([1.2.7], [PINP_SDL], [yes])

AC_CONFIG_FILES([Makefile src/Makefile])
AC_CONFIG_HEADERS([src/config.h:src/config.h.in])
AC_OUTPUT

echo "
Configuration for $PACKAGE_TARNAME $PACKAGE_VERSION:
	Enable debug:             $MODE_DEBUG
	Enable optimizations:     $optimizations
	Compiler flags:           $CFLAGS
	Linker flags:             $LDFLAGS
	Libs:                     $LIBS
	Install prefix:           $prefix
Type 'make' to build and 'make install' to install $PACKAGE."
