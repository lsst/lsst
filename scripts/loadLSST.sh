#! /bin/sh
#
#  Source this file directly or copy it to your own directory for 
#  modifications. 
#
export LSST_HOME=#LSST_HOME   #Replace with proper value
export LSST_PKGROOT=#EUPS_PKGROOT   #Replace with proper value

if [ -z "$EUPS_PKGROOT" ]; then
    export EUPS_PKGROOT=$LSST_PKGROOT
fi 

# Load EUPS
. $LSST_HOME/eups/default/bin/setups.sh

# make sure LSST_DEVEL is part of the EUPS path
if [ -n "$LSST_DEVEL" ]; then
    if [ -e "$LSST_DEVEL/ups_db" ]; then
        target=`ls -id1 $LSST_DEVEL | awk '{print $1}'`
        ls -id1 `echo $EUPS_PATH | sed -e 's/:/ /g'` | egrep -q "^${target} "
        if [ $? != 0 ]; then
            export EUPS_PATH="${LSST_DEVEL}:$EUPS_PATH"
        fi  
    else 
        echo "LSST_DEVEL=${LSST_DEVEL}: "
        echo "    Not setup for EUPS (no ups_db directory); ignoring..."
    fi
fi

# set the LSST_PKGS var
if [ -z "$LSST_PKGS" ]; then
    if [ -n "$EUPS_FLAVOR" ]; then
        flv="$EUPS_FLAVOR"
    else
        flv=`eups flavor`
    fi
    export LSST_PKGS="$LSST_HOME/$flv"
    flv=
fi

# Setup your default environemnt
setup lsst

