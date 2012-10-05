#! /bin/csh -f
#
#  Source this file directly or copy it to your own directory for 
#  modifications. 
#
setenv LSST_HOME #LSST_HOME   #Replace with proper value

# Load EUPS
source $LSST_HOME/eups/default/bin/setups.csh

# make sure LSST_DEVEL is part of the EUPS path
if ($?LSST_DEVEL) then
    if (-e "$LSST_DEVEL/ups_db") then
        set target = `ls -id1 $LSST_DEVEL | awk '{print $1}'`
        ls -id1 `echo $EUPS_PATH | sed -e 's/:/ /g'` | egrep -q "^${target} "
        if ($status != 0) then
            setenv EUPS_PATH "${LSST_DEVEL}:$EUPS_PATH"
        endif
    else 
        echo "LSST_DEVEL=${LSST_DEVEL}: "
        echo "    Not setup for EUPS (ups_db directory is missing); ignoring..."
    endif
endif

# set the LSST_PKGS var
if (! $?LSST_PKGS) then
    if ($?EUPS_FLAVOR) then
        set flv = "$EUPS_FLAVOR"
    else
        set flv = `eups flavor`
    endif
    setenv LSST_PKGS $LSST_HOME/`eups flavor`
    unset flv
endif

# Setup your default environment
setup lsst

