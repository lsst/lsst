dnl -*- sh -*-
dnl A configure.ac script that checks that all of LSST's prerequisites are present
dnl
AC_INIT([LSST], "1.0", [rhl@astro.princeton.edu])

dnl sinclude is m4's include directive
dnl sinclude(configMacros/zlib.m4)

AC_PROG_CC
AC_PROG_CXX

AC_CHECK_PROG(curl, curl, yes)
AC_PROG_FC
AC_PROG_LEX
AC_CHECK_PROG(make, make, yes)
AC_CHECK_PROG(perl, perl, yes)
AC_PROG_YACC
AC_CHECK_PROGS(M4, m4, gm4)

if [[ `uname` = "Linux" ]]; then
   :
fi

AC_CHECK_HEADERS(X11/Intrinsic.h)
if [[ `uname` = "Darwin" ]]; then
    LDFLAGS="$LDFLAGS -L/usr/X11/lib"
fi
AC_CHECK_LIB(Xt, XtAddActions)

AC_CHECK_HEADERS(curses.h)
AC_CHECK_LIB(curses, cbreak)

AC_CHECK_HEADERS(readline/readline.h)
AC_CHECK_LIB(readline, readline)
# if readline is absent, try editline instead
if [[ $ac_cv_header_readline_readline_h != "yes" ]]; then
   AC_CHECK_HEADERS(editline/readline.h)
   AC_CHECK_LIB(editline, readline)
   ac_cv_header_readline_readline_h=$ac_cv_header_editline_readline_h
   ac_cv_lib_readline_readline=$ac_cv_lib_editline_readline
fi

dnl AC_CHECK_HEADERS(ext2fs/ext2_io.h)

AC_CHECK_HEADERS(uuid/uuid.h)
if [[ `uname` = "Darwin" ]]; then
    AC_CHECK_LIB(System, uuid_parse)
    ac_cv_lib_uuid_uuid_parse=$ac_cv_lib_System_uuid_parse
else
    AC_CHECK_LIB(uuid, uuid_parse)
fi

AC_CHECK_HEADERS(zlib.h)
AC_CHECK_LIB(z, zlibVersion)

AC_CHECK_HEADERS(bzlib.h)
AC_CHECK_LIB(bz2, BZ2_bzlibVersion)

dnl
dnl Report what we have found out
dnl
ok=yes
echo ""

dnl AC_MSG_RESULT([N.b. we are not checking for e2fsprogs])

if [[ "$ac_cpp" = "" ]]; then
   AC_MSG_WARN([Please install a C compiler (gcc on RHEL6)])
   ok=no
fi

if [[ "$ac_ct_CXX" = "" ]]; then
   AC_MSG_WARN([Please install a C++ compiler (gcc-c++ on RHEL6)])
   ok=no
fi

if [[ "$ac_cv_prog_curl" = "" ]]; then
   AC_MSG_WARN([Please install curl (curl on RHEL6)])
   ok=no
fi

if [[ "$ac_ct_FC" = "" ]]; then
   if false; then
      AC_MSG_RESULT([I don't see a fortran compiler.  This is probably OK])
   else
      AC_MSG_WARN([Please install a fortran compiler if you're building numpy (gcc-gfortran on RHEL6)])
      ok=no
   fi
fi

if [[ "$ac_cv_prog_LEX" = "" ]]; then
    AC_MSG_WARN([Please install flex (flex on RHEL6)])
    ok=no
fi

if [[ "$ac_cv_prog_make" = "" ]]; then
   AC_MSG_WARN([Please install make (make on RHEL6)])
   ok=no
fi

if [[ "$ac_cv_prog_perl" = "" ]]; then
   AC_MSG_WARN([Please install perl (perl on RHEL6)])
   ok=no
fi

if [[ "$ac_cv_prog_YACC" = "" ]]; then
    AC_MSG_WARN([Please install bison (bison on RHEL6)])
    ok=no
fi

if [[ "$ac_cv_prog_M4" = "" ]]; then
   AC_MSG_WARN([Please install m4 (m4 on RHEL6)])
   ok=no
fi
 
if [[ $ac_cv_header_X11_Intrinsic_h != "yes" -o ${ac_cv_lib_Xt_XtAddActions} != "yes" ]]; then
   AC_MSG_WARN([Please install X11 (libXt-devel on RHEL6)])
   ok=no
fi

if [[ $ac_cv_header_curses_h != "yes" -o $ac_cv_lib_curses_cbreak != "yes" ]]; then
   AC_MSG_WARN([Please install curses (ncurses-devel on RHEL6)])
   ok=no
fi

if [[ $ac_cv_header_readline_readline_h != "yes" -o $ac_cv_lib_readline_readline != "yes" ]]; then
   AC_MSG_WARN([Please install readline or editline (readline-devel on RHEL6))])
   ok=no
fi

if [[ $ac_cv_header_uuid_uuid_h != "yes" -o $ac_cv_lib_uuid_uuid_parse != "yes" ]]; then
   AC_MSG_WARN([Please install libuuid (libuuid-devel on RHEL6)])
   ok=no
fi

dnl if [[ $ac_cv_header_ext2fs_ext2_io_h != "yes" ]]; then
dnl    AC_MSG_WARN([Please install e2fsprogs (e2fsprogs-devel on RHEL6)])
dnl    ok=no
dnl fi

if [[ $ac_cv_header_zlib_h != "yes" -o $ac_cv_lib_z_zlibVersion != "yes" ]]; then
   AC_MSG_WARN([Please install zlib (zlib-devel on RHEL6)])
   ok=no
fi
if [[ $ac_cv_header_bzlib_h != "yes" -o $ac_cv_lib_bz2_BZ2_bzlibVersion != "yes" ]]; then
   AC_MSG_WARN([Please install bzip2 (bzip2-devel on RHEL6)])
   ok=no
fi

dnl
dnl Well, are we winning?
dnl
if [[ $ok = "yes" ]]; then
   AC_MSG_RESULT([You seem to have all prerequisites installed; congratulations.])
fi
