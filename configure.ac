dnl -*- bash -*-
dnl A configure.ac script that checks that all of LSST's prerequisites are present
dnl
AC_INIT([LSST], "1.0", [rhl@astro.princeton.edu])

dnl sinclude is m4's include directive
dnl sinclude(configMacros/zlib.m4)

AC_PROG_CC
AC_PROG_CXX

AC_PROG_FC
AC_PROG_LEX
AC_PROG_YACC
AC_CHECK_PROGS(M4, m4, gm4)

if [[ `uname` = "Linux" ]]; then
   :
fi

AC_CHECK_HEADERS(X11/Intrinsic.h)
AC_CHECK_HEADERS(curses.h)
AC_CHECK_HEADERS(readline/readline.h)
dnl AC_CHECK_HEADERS(ext2fs/ext2_io.h)

# if readline is absent, try editline instead
if [[ $ac_cv_header_readline_readline_h = "no" ]]; then
   AC_CHECK_HEADERS(editline/readline.h)
   ac_cv_header_readline_readline_h=$ac_cv_header_editline_readline_h
fi
AC_CHECK_HEADERS(zlib.h)
dnl
dnl Report what we've found out
dnl
ok=yes
echo ""

AC_MSG_RESULT([N.b. we are not checking libtool and e2fsprogs-devel])

if [[ "$ac_cpp" = "" ]]; then
   AC_MSG_WARN([Please install a C compiler (e.g. gcc-c++)])
   ok=no
fi

if [[ "$ac_ct_CXX" = "" ]]; then
   AC_MSG_WARN([Please install a C++ compiler (e.g. gcc-c++)])
   ok=no
fi

if [[ "$ac_ct_FC" = "" ]]; then
   dnl RHL thinks that we don't need to check fortran
   if true; then
      AC_MSG_RESULT([I don't see a fortran compiler.  This is probably OK])
   else
      AC_MSG_WARN([Please install a fortran compiler (e.g. gcc-fortran)])
      ok=no
   fi
fi

if [[ " $ac_cv_prog_LEX" = "" ]]; then
   AC_MSG_WARN([Please install flex])
   ok=no
fi

if [[ " $ac_cv_prog_YACC" = "" ]]; then
   AC_MSG_WARN([Please install yacc (or bison)])
   ok=no
fi

if [[ " $ac_cv_prog_M4" = "" ]]; then
   AC_MSG_WARN([Please install m4])
   ok=no
fi
 
if [[ $ac_cv_header_X11_Intrinsic_h = "no" ]]; then
   AC_MSG_WARN([Please install libXt-devel])
   ok=no
fi

if [[ $ac_cv_header_curses_h = "no" ]]; then
   AC_MSG_WARN([Please install ncurses-devel])
   ok=no
fi

if [[ $ac_cv_header_readline_readline_h = "no" ]]; then
   AC_MSG_WARN([Please install readline-devel (or editline-devel)])
   ok=no
fi

dnl if [[ $ac_cv_header_ext2fs_ext2_io_h = "no" ]]; then
dnl    AC_MSG_WARN([Please install e2fsprogs-devel])
dnl    ok=no
dnl fi

if [[ $ac_cv_header_zlib_h = "no" ]]; then
   AC_MSG_WARN([Please install zlib-devel])
   ok=no
fi

dnl
dnl Well, are we winning?
dnl
if [[ $ok = "yes" ]]; then
   AC_MSG_RESULT([You seem to have all prerequisites installed; congratulations])
fi
