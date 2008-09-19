#! /bin/bash
#  
#  A build clean-up script.  This script has some built in safety to protect
#  against a programmer error doing some bad things
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

# Read in definitions and funtion definitions
#
. $libdir/build_functions.sh

. $libdir/definitions.sh || {
    echo Failure reading macros in $libdir/definitions
    exit 5
}

trap "onexit" 0

tmpdir=$PWD
builddir=
while [ $# -gt 0 ]; do
    case "$1" in 
        -t) tmpdir="$2"; shift;;
        -b) builddir="$2"; shift;;
        *)  break;;
    esac
    shift
done

normsemaphore=
[ -z "$builddir" ] && builddir="$tmpdir/$product-$version"
if [ -e "$builddir/$build_semaphore" ]; then
    echo $prog: Another build apparently in progress in $builddir
    normsemaphore=1
    exit 2
fi

if [ -d "$builddir" ]; then
    touch "$builddir/$build_semaphore" || {
        echo "Failed to write to $builddir"
        exit 1
    }

    empty_build_dir
#    echo rmdir $builddir
#    rmdir $builddir || {
#        echo $prog: Failed to remove $builddir
#        exit 1
#    }
fi

exit 0
