#! /bin/bash
#
# standard for commands definitions
#
make=`/usr/bin/which make`
if [ $? -ne 0 -o -z "$make" ]; then
    failed_to_find_cmd make; exit $?
fi

httpget=`/usr/bin/which curl` || httpget=`/usr/bin/which wget`
if [ $? -ne 0 -o -z "$httpget" ]; then
    return fail_to_find_cmd make
elif [ `basename $httpget` = 'wget' ]; then
    httpget="$httpget -O -"
fi

rmcmd=/bin/rm
[ -x "$rmcmd" ] || rmcmd=/usr/bin/rm

bldext=bld
buildlog=build.log
internalbuildfile="distrib.$bldext"
build_semaphore="_BUILDING_"
defsetupfile="./eupssetups.sh"
sconsopt="opt=3"

tmpdir=
installdir=
fromdistrib=
dosetupr=
pkgbase=`echo $EUPS_PKGROOT | sed -e 's/\s*|.*$//'`

function process_command_line {

    while [ $# -gt 0 ]; do
        case "$1" in 
            -D) fromdistrib="1" ;;
            -b) builddir="$2"; shift;;
            -o) sconsopt="opt=$2"; shift;;
            -p) export EUPS_PATH="$2"; shift;;
            -r) pkgbase="$2"; shift;;
            -t) tmpdir="$2"; shift;;
            *)  break;;
        esac
        shift
    done

    distfile=`echo $1`    # strip spaces
    installdir=`echo $2`
    product=`echo $3` 
    version=`echo $4`

    if [ -z "$distfile" ]; then
        echo "$prog: source distribution file argument missing"
        return 1
    fi

    local tmp 
    if [ -z "$version" ]; then
        if [ -n "$installdir" ]; then
            version=`basename $installdir`
            if [ -z "$product" ]; then
                tmp=`dirname $installdir`
                product=`basename $tmp`
            fi
        else
            tmp=`basename $distfile | sed -e '/\.tar\.gz$/ s/\.gz$//' -e 's/\.[^.]*$//'`
            product=`echo $tmp | sed -e 's/-.*$//'`
            version=`echo $tmp | sed -e 's/^[^\-]*-//'`
        fi
    fi
    if [ -z "$installdir" -a -n "$product" -a -n "$version" -a -n "$LSST_HOME" ]; then
        # assume this is an external package (because LSST packages 
        # know where to go)
        installdir="$LSST_HOME/external/$product/$version"
    fi

    for arg in product version installdir distfile; do
        eval argval=\$$arg
        if [ -z "$argval" ]; then
            echo "$prog: $arg argument missing"
            return 1
        fi
    done

    if [ -z "$builddir" ]; then
        [ -n "$tmpdir" ] || tmpdir=$PWD
        builddir="$tmpdir/$product-$version"
    fi

    if [ -z "$fromdistrib" ]; then
        # when eups distrib is building, an eupssetup.sh file will be provided
        # that sets up the environement; thus, we will ignore the dependencies
        # specified in the table file.  
        setupTableDeps="1"
    fi

    return 0
}

function failed_to_find_cmd {
    echo Failed to find $1 command
    return 5
}

