lsst
====

[![Build Status](https://travis-ci.org/lsst/lsst.png)](https://travis-ci.org/lsst/lsst)

This package sets up a basic environment needed to:

  1.  install packages from the LSST software server
  2.  build LSST products from git
  3.  build external software that uses LSST products

For building products, this package provides the following:

  *  it sets two useful environment variables that saves typing when
     checking out packages from the SVN repository:

     + LSST_GIT     The Git repository's base URL, git@git.lsstcorp.org
     + LSST_DMS     The base Git URL to the directory containing
                       LSST products

  *  it setups up the base package, which is necessary for properly
     loading LSST python modules.

For managing products, this package provides the following:

   *  prepends the address of the LSST software distribution server to
      EUPS_PKGROOT environment variable.

   DEPRECATED: the package also sets up the following variables, but they're
   deprecated and should not be used in future code/scripts.

     *  sets the LSST_HOME environment variable to the root of the LSST
        software stack.  This is the directory where the loadLSST scripts are
        found.

     *  sets the LSST_PKGROOT and (if not already set) the EUPS_PKGROOT
        environment variables.  The latter is used by "eups distrib" for
        retrieving and installing new product packages.  If EUPS_PKGROOT is not
        already set, it is set to the value of $LSST_PKGROOT

     *  sets the LSST_PKGS environment variable to the platform-specific
        subdirectory of $LSST_HOME where LSST packages are installed.

     *  if $LSST_DEVEL is set, it is added the the start of the
        EUPS_PATH environment variable.  $EUPS_PATH has a list of of
        colon-delimited directories that EUPS uses to look for software
        products to load.  A user may set LSST_DEVEL if they want to install
        packages but do not have permission to write to LSST_HOME.  By placing
        it at the front of EUPS_PATH, newly installed packages will be
        installed under $LSST_DEVEL.

