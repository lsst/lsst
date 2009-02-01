#! /usr/bin/env bash
#  
#  A wrapper build script
#
#  Usage:
#     lssteupsbuild.sh [ -b buildDir ] [ -t buildDirRoot ] 
#           distribFile [ installDir [ product version ]]
#  Options:
#     -b buildDir        build the product in this directory 
#     -p eupsPath        the value of EUPS_PATH
#     -r pkgRoot         the base server URL for retrieving files from 
#                          the package server
#     -t buildDirRoot    if -b is not provided create and use a default 
#                          build directory below this directory.
#  Arguments:
#     distribFile  the location file downloaded from the distribution server
#     installDir   the directory to install the product into
#     product      the name of the product being built
#     version      the product version
#
prog=`basename $0`
builddir=

# Make sure the lssteups package is properly setup
#
if [ -z "$LSSTEUPS_DIR" ]; then
    echo "$prog: lssteups package is not setup"
    exit 1
fi
if [ ! -d "$LSSTEUPS_DIR" -o ! -r "$LSSTEUPS_DIR" ]; then
    echo "$prog: lssteups package dir $LSSTEUPS_DIR not found/readable"
    exit 1
fi
libdir=$LSSTEUPS_DIR/lib
if [ ! -d "$libdir"  -o ! -r "$libdir" ]; then
    echo "$prog: lssteups lib dir $libdir not found"
    exit 1
fi

# Read in definitions and function definitions
#
. $libdir/build_functions.sh

. $libdir/definitions.sh || {
    echo Failure reading macros in $libdir/definitions
    exit 5
}

# Make sure eups is setup and we are not root
#
if eups_not_setup || user_is_root; then
    exit 1
fi

trap "onexit" 0
trap "interrupted" 1 2 3 13 15

process_command_line $* || exit $?

if [ -z "$builddir" ]; then
    echo $prog: Build directory not defined; can not proceed
    exit 1
fi

# change into the build directory; expect it to exist already (as it holds
# the file we are processing)
if [ ! -d "$builddir" ]; then
    echo $prog: $build: Build directory not found
    exit 1
fi
normsemaphore=
if [ -e "$builddir/$build_semaphore" ]; then
    echo $prog: Another build apparently in progress in $builddir
    normsemaphore=1
    exit 2
fi
touch "$builddir/$build_semaphore"
cd $builddir

[ -e "$buildlog" ] && cat < /dev/null > $buildlog

# run the setup commands that load the environment
setupfile=
[ -n "$defsetupfile" -a -f "$defsetupfile" ] && setupfile=$defsetupfile
if [ -n "$setupfile" ]; then
    echo "Setting up environment (via $setupfile)..."
    . $setupfile || {
        echo $prog: Failed to load environment from $setupfile
        exit 1
    }
fi

if [ ! -e "$distfile" ]; then
    echo $prog: $distfile: File not found
    exit 1
fi
if echo $distfile | grep -q $bldext\$; then

    # execute the build script
    run_build_file $distfile || {
        echo $prog: Problem running build script, $file
        exit 1
    }

elif echo $distfile | egrep -q '.tar$|.tar.gz$'; then

    # unpack the tar file and descend into it
    unpack_tar_and_build $distfile || exit 1

else

    echo "$prog: Don't know how to build $distfile"
    exit 1

fi

cd $builddir

exit 0

