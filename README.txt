Package: lsst

This package ensures a basic environment needed to:

  1.  install packages from the LSST software server
  2.  build LSST products from svn
  3.  build external software that use LSST products

This package will be setup by default if the user initializes her
environment by sourcing the loadLSST.*sh script (installed in
$LSST_HOME, the root directory of the LSST software stack; see "Using
loadLSST" below).  If the user does not use this script, he can simply
run "setup lsst" instead.

When this package is setup, it will:

  o  setup the lssteups package, which is required for downloading
       packages from sw.lsstcorp.org.

  o  provides useful commands for managing packages:
     + switcheups:  a script that will switch the version of eups
                       that will be loaded when sourcing loadLSST.*sh
     + lsstpkg:     a thin wrapper around eups distrib.  Using this
                       script guarantees that the lssteups extensions
                       will be used (deprecated).

For building products, this package provides the following:

  o  it sets two useful environment variables that saves typing when
     checking out packages from the SVN repository:

     + LSST_GIT     The Git repository's base URL, git@git.lsstcorp.org
     + LSST_DMS     The base Git URL to the directory containing 
                       LSST products

  o  it setups up the base package, which is necessary for properly
     loading LSST python modules.

Using loadLSST

This package also provides the scripts loadLSST.sh and loadLSST.csh
scripts.  A user may initialize his/her LSST environment by sourcing
the appropriate version.  These files are usually installed when the
software stack is first deployed according to the instructions in
doc/GettingStarted.html.  Sourcing this file does the following:

   o  sets the LSST_HOME environment variable to the root of the LSST
        software stack.  This is the directory where the loadLSST
        scripts are found.  

   o  sets the LSST_PKGROOT and (if not already set) the EUPS_PKGROOT
        environment variables.  The latter is used by "eups distrib"
        for retrieving and installing new product packages.  If 
        EUPS_PKGROOT is not already set, it is set to the value of 
        $LSST_PKGROOT

   o  sets the LSST_PKGS environment variable to the platform-specific 
        subdirectory of $LSST_HOME where LSST packages are installed.

   o  loads EUPS into the environment

   o  if $LSST_DEVEL is set, it is added the the start of the
        EUPS_PATH environment variable.  $EUPS_PATH has a list of of 
        colon-delimited directories that EUPS uses to look for software 
        products to load.  A user may set LSST_DEVEL if they want to
        install packages but do not have permission to write to
        LSST_HOME.  By placing it at the front of EUPS_PATH, newly
        installed packages will be installed under $LSST_DEVEL.

   o  it sets up the lsst package.  

Users do not have to source this file to use the LSST software stack.
If eups is already set up, then a user need only run "setup lsst" to
load the environment.  Sourcing loadLSST.*sh is a convenience for
users that don't normally have eups already set up.  Users may put the
source command in their shell starup file.  Alternatively, they may
take a copy and edit for their own preferences; in particular, this
may be adding other setup commands.  

The loadLSST scripts can be installed into LSST_HOME by typing 
"scons loadLSST"  

