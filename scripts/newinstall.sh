#!/bin/bash
#
# Bootstrap lsst stack install by:
#   * Installing EUPS
#   * Install everything up to the lsst package
#

set -e

EUPS_PKGROOT="http://lsst-web.ncsa.illinois.edu/~mjuric/pkgs"
LSST_HOME="$PWD"

##########  1. Install EUPS

git clone https://github.com/mjuric/eups.git
cd eups
./configure --prefix="$LSST_HOME"/eups --with-eups="$LSST_HOME"
make install

##########  2. Install the Basic Environment

SHELL=/bin/bash
source "$LSST_HOME"/eups/bin/setups.sh
eups distrib install lsst

##########  3. Create the environment loader scripts

for sfx in sh csh ksh; do
	cat > "$LSST_HOME"/loadLSST.$sfx <<-EOF
		# Source this script to load the minimal LSST environment
		source "$LSST_HOME"/eups/bin/setups.$sfx
		setup lsst
	EOF
done

##########  4. Helpful message about what to do next

cat <<-EOF
	Bootstrap complete.

	To continue installing (and use) the LSST stack type one of:

		source "$LSST_HOME/loadLSST.sh"		# for bash
		source "$LSST_HOME/loadLSST.csh"	# for csh
		source "$LSST_HOME/loadLSST.ksh"	# for ksh

	Individual LSST packages may now be installed with the usual `eups
	distrib install' command.  For example, to install the entire LSST
	stack, use:

		eups distrib install lsst_distrib

	Thank you for using LSST code!
			-- Your codemongering friends at http://lsst.org
EOF;
