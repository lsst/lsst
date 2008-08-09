#! /bin/bash
#
# Usage: sh newinstall.sh [package ...]
#
#  Set up some initial environment variables
#
# set -x
SHELL=/bin/bash
LSST_HOME=$PWD
export EUPS_PKGROOT=#EUPS_PKGROOT   #Replace with proper value
owneups=
httpget=

while [ $# -gt 0 ]; do
    case "$1" in 
        -H) LSST_HOME="$2"; shift;;
        -E) owneups="1";;
        -w) httpget="$2"; shift;;
        -r) EUPS_PKGROOT="$2"; shift;;
        *)  break;;
    esac
    shift
done
cd $LSST_HOME

if [ -z "$httpget" ]; then
    httpget=`/usr/bin/which curl` || httpget=`/usr/bin/which wget`
    if [ $? -ne 0 -o -z "$httpget" ]; then
        echo "Can't find curl or wget on your system; try to give path via -w"
        exit 1
    fi
fi
if [ `basename $httpget` = 'wget' ]; then
    httpget="$httpget -O -"
fi


# Create the initial set of directories 
#
mkdir -p eups _build_
cat > _build_/README <<EOF
This directory is used to build packages, 
EOF

# Download and install EUPS
# 
if [ -z "$owneups" ]; then
    cd _build_ && mkdir eups-default && cd eups-default

    echo "Pulling down EUPS..."
    $httpget $EUPS_PKGROOT/external/eups/eups-default.tar.gz >eups-default.tar.gz
    eupsdir=`tar tzf eups-default.tar.gz | grep / | head -1 | sed -e 's/\/.*$//'`
    tar xzf eups-default.tar.gz

    if [ -n "$eupsdir" ]; then
        cd $eupsdir
        echo "Installing EUPS..."
        eupsver=`echo $eupsdir | sed -e 's/^eups-//'`
        echo ./configure --prefix=$LSST_HOME/eups/$eupsver --with-eups=$LSST_HOME --with-eups_dir=$LSST_HOME/eups/$eupsver
        ls Makefile.in
        ./configure --prefix=$LSST_HOME/eups/$eupsver --with-eups=$LSST_HOME --with-eups_dir=$LSST_HOME/eups/$eupsver || {
            echo "Failed to configure EUPS"
            exit 2
        }
        echo make install
        make install > make-install.log 2>&1 || {
            cat make-install.log
            echo "Failed to install EUPS"
            exit 2
        }
        head -4 make-install.log
    else
        echo "I don't see what EUPS unpacked into"
        exit 2
    fi

    cd $LSST_HOME/eups || exit 2
    [ -e default ] && rm default
    ln -s $eupsver default
    cd $LSST_HOME || exit 2
    rm -rf _build_/eups-default

    # load EUPS into the environment
    source eups/default/bin/setups.sh

else

    if [ -z "$EUPS_DIR" ]; then
        echo "User's EUPS_DIR is not set; set up EUPS or do not use -E"
        exit 1
    fi
    echo "Warning: Using local EUPS installation at $EUPS_DIR"
    mkdir -p ups_db

fi

mkdir `eups flavor`

# install the LSST EUPS extension package

eups distrib install -v -r $EUPS_PKGROOT/bootstrap lssteups || {
    echo "Failed to install lssteups, LSST's EUPS extension package"
    exit 2
}
[ -d "EupsBuildDir" ] && rm -rf EupsBuildDir
setup lssteups

# install the essential stuff
# eups distrib install build
eups distrib install python

while [ $# -gt 0 ]; do
    eups distrib install "$1"
    shift
done
