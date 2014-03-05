#!/bin/bash
#
# Bootstrap lsst stack install by:
#   * Installing EUPS
#   * Installing Anaconda Python distribution, if necessary
#   * Install everything up to the lsst package
#   * Creating the loadLSST.xxx scripts
#

set -e

EUPS_PKGROOT="http://lsst-web.ncsa.illinois.edu/~mjuric/pkgs"
LSST_HOME="$PWD"

echo

##########  1. Refuse to run from a non-empty directory

if true; then
	if [[ ! -z "$(ls -A)" ]]; then
		echo "Please run this script from an empty directory. The LSST stack will be installed into it."
		exit -1;
	fi
fi

##########  1. Install EUPS

if true; then
	PYTHON="${PYTHON:-/usr/bin/python}"
	if [[ ! -x "$PYTHON" ]]; then
		echo "Cannot find or execute '$PYTHON'. Please set the PYTHON environment variable to point to system Python 2 interpreter and rerun."
		exit -1;
	fi

	echo -n "Installing EUPS ... "
	(

		mkdir _build && cd _build
		git clone https://github.com/mjuric/eups.git
		cd eups
		git checkout eupspkg
		./configure --prefix="$LSST_HOME"/eups --with-eups="$LSST_HOME" --with-python="$PYTHON"
		make install
	) > eupsbuild.log 2>&1 && echo " done." || { echo " FAILED."; echo "See log in eupsbuild.log"; exit -1; }

fi

##########  2. Source EUPS

set +e
source "$LSST_HOME/eups/bin/setups.sh"
set -e

##########  2. Test Python version, offer to get anaconda if too old

if true; then
	PYVEROK=$(python -c 'import sys; print("%i" % (sys.hexversion >= 0x02070000 and sys.hexversion < 0x03000000))')
	if [[ $PYVEROK != 1 ]]; then
cat <<-EOF

		LSST stack requires Python 2.7; you seem to have $(python -V 2>&1) on your
		path ($(which python)).  Please set up a compatible python interpreter,
		prepend it to your PATH, and rerun this script.  Alternatively, we can set
		up the Anaconda Python distribution for you.  It will be managed by LSST's
		EUPS package manager, and will not replace or modify your system python.

EOF

		while true; do
			read -p "Would you like us to install Anaconda Python distribution (if unsure, say yes)? " yn
			case $yn in
				[Yy]* ) 
					echo
					echo "Installing Anaconda Python Distribution ... "
					eups distrib install --repository="$EUPS_PKGROOT" anaconda
					setup anaconda
					CMD_SETUP_ANACONDA='setup anaconda'
					break ;;
				[Nn]* ) 
					echo
					echo "Thanks. After you set up Python 2.7 yourself, rerun this script to"
					echo "continue the installation."
					echo
					exit ;;
				* ) echo "Please answer yes or no.";;
			esac
		done
	fi
fi

##########  2. Install the Basic Environment

if true; then
	echo "Installing the basic environment ... "
	eups distrib install --repository="$EUPS_PKGROOT" lsst
fi

##########  3. Create the environment loader scripts

for sfx in sh csh ksh; do
	echo -n "Creating startup scripts ($sfx) ... "
	cat > "$LSST_HOME"/loadLSST.$sfx <<-EOF
		# Source this script to load the minimal LSST environment
		source "$LSST_HOME/eups/bin/setups.$sfx"
		$CMD_SETUP_ANACONDA
		setup lsst
	EOF
	echo " done."
done

##########  4. Helpful message about what to do next

cat <<-EOF
	
	Bootstrap complete. To continue installing (and to use) the LSST stack
	type one of:

	    source "$LSST_HOME/loadLSST.sh"    # for bash
	    source "$LSST_HOME/loadLSST.csh"   # for csh
	    source "$LSST_HOME/loadLSST.ksh"   # for ksh

	Individual LSST packages may now be installed with the usual \`eups
	distrib install' command.  For example, to install the science pipeline
	elements of the LSST stack, use:

	    eups distrib install lsst_apps

	Next, read the documentation at:
	
	    https://confluence.lsstcorp.org/display/LSWUG/LSST+Software+User+Guide

	and feel free to ask any questions via our mailing list at:
	
	    http://listserv.lsstcorp.org/mailman/listinfo/lsst-dm-stack-users

	                                   Thanks!
	                                           -- The LSST Software Teams

EOF
