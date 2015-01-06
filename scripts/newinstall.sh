#!/bin/bash

# Please preserve tabs as indenting whitespace at Mario's request
# to keep heredocs nice (--fe)
# Use 4-character tabs to match python indent look
#
# **** This file should not be edited in place ****
# It is maintained in a repository at
# git@git.lsstcorp.org:LSST/DMS/devenv/lsst
# 
# If the file must be modified, clone the repository
# and edit there.
# *************************************************
#
# Bootstrap lsst stack install by:
#	* Installing EUPS
#	* Installing Anaconda Python distribution, if necessary
#	* Install everything up to the lsst package
#	* Creating the loadLSST.xxx scripts
#

set -e

#
# Note to developers: change these when the EUPS version we use changes
#

EUPS_VERSION=${EUPS_VERSION:-1.3.0}

EUPS_GITREV=${EUPS_GITREV:-""}
EUPS_GITREPO=${EUPS_GITREPO:-"https://github.com/RobertLuptonTheGood/eups.git"}
EUPS_TARURL=${EUPS_TARURL:-"https://github.com/RobertLuptonTheGood/eups/archive/$EUPS_VERSION.tar.gz"}

EUPS_PKGROOT=${EUPS_PKGROOT:-"http://sw.lsstcorp.org/eupspkg"}

LSST_HOME="$PWD"

cont_flag=false
batch_flag=false
help_flag=false

# Use system python to bootstrap unless otherwise specified
PYTHON="${PYTHON:-/usr/bin/python}"

while getopts cbhP: optflag; do
	case $optflag in
		c)
			cont_flag=true
			;;
		b)
			batch_flag=true
			;;
		h)
			help_flag=true
			;;
		P)
			PYTHON=$OPTARG
	esac
done

shift $((OPTIND - 1))

if [[ "$help_flag" = true ]]; then
	echo
	echo "usage: newinstall.sh [-b] [-f] [-h]"
	echo " -b -- Run in batch mode.	 Don't ask any questions and install all extra packages."
	echo " -c -- Attempt to continue a previously failed install."
	echo " -P [PATH_TO_PYTHON] -- Use a specific python to bootstrap the stack."
	echo " -h -- Display this help message."
	echo
	exit 0
fi

echo
echo "LSST Software Stack Builder"
echo "======================================================================="
echo

##########	Refuse to run from a non-empty directory

if [[ "$cont_flag" = false ]]; then
	if [[ ! -z "$(ls)" && ! "$(ls)" == "newinstall.sh" ]]; then
		echo "Please run this script from an empty directory. The LSST stack will be installed into it."
		exit -1;
	fi
fi


##########	Offer to get git if it's too old

if true; then
	if hash git 2>/dev/null; then
		GITVERNUM=$(git --version | cut -d\	 -f 3)
		GITVER=$(printf "%02d-%02d-%02d\n" $(echo "$GITVERNUM" | cut -d. -f1-3 | tr . ' '))
	fi
	
	if [[ $GITVER < "01-08-04" ]]; then
		if [[ "$batch_flag" = true ]]; then
			WITH_GIT=1
		else
			cat <<-EOF
			Detected $(git --version).

			The git version control system is frequently used with LSST software. While
			the LSST stack should build and work even in the absence of git, we don't
			regularly run and test it in such environments. We therefore recommend you
			have at least git 1.8.4 installed, or let this script install it for you.

			git installed by this installer will be managed by LSST's EUPS package manager,
			and will not replace or modify any other version of git you may have installed
			on your system.

			EOF
			
			while true; do
				read -p "Would you like us to install git for you (if unsure, say yes)? " yn
				case $yn in
					[Yy]* )
						WITH_GIT=1
						break
						;;
					[Nn]* )
						echo "git will not be installed."
						break;
						;;
					* ) echo "Please answer yes or no.";;
				esac
			done
		fi
	else
		echo "Detected $(git --version). OK."
	fi
	echo
fi

##########	Test/warn about Python versions, offer to get anaconda if too old

if true; then
	PYVEROK=$(python -c 'import sys; print("%i" % (sys.hexversion >= 0x02070000 and sys.hexversion < 0x03000000))')
	if [[ "$batch_flag" = true ]]; then
		WITH_ANACONDA=1
	else
		if [[ $PYVEROK != 1 ]]; then
		cat <<-EOF
			LSST stack requires Python 2.7; you seem to have $(python -V 2>&1) on your
			path ($(which python)).	 Please set up a compatible python interpreter,
			prepend it to your PATH, and rerun this script.	 Alternatively, we can set
			up the Anaconda Python distribution for you.
			EOF
		fi
		
		cat <<-EOF

		In addition to Python 2.7, some LSST packages depend on recent versions of numpy,
		matplotlib, and scipy. If you don't have all of these, the installation may fail.
		Using the Anaconda Python distribution will ensure all these are set up.

		Anaconda Python installed by this installer will be managed by LSST's EUPS
		package manager, and will not replace or modify your system python.

		EOF
		
		while true; do
		read -p "Would you like us to install Anaconda Python distribution (if unsure, say yes)? " yn
		case $yn in
			[Yy]* )
				WITH_ANACONDA=1
				break
				;;
			[Nn]* )
				if [[ $PYVEROK != 1 ]]; then
			echo
			echo "Thanks. After you install Python 2.7 and the required modules, rerun this script to"
			echo "continue the installation."
			echo
			exit
				fi
				break;
				;;
			* ) echo "Please answer yes or no.";;
		esac
		done
		echo
	fi
fi

##########	Install EUPS

if true; then
	if [[ ! -x "$PYTHON" ]]; then
		echo -n "Cannot find or execute '$PYTHON'. Please set the PYTHON environment variable or use the -P"
		echo " option to point to system Python 2 interpreter and rerun."
		exit -1;
	fi
	
	if [[ "$PYTHON" != "/usr/bin/python" ]]; then
		echo "Using python at $PYTHON to install EUPS"
	fi
	
	if [[ -z $EUPS_GITREV ]]; then
		echo -n "Installing EUPS (v$EUPS_VERSION)... "
	else
		echo -n "Installing EUPS (branch $EUPS_GITREV from $EUPS_GITREPO)..."
	fi
	
	(
	mkdir _build && cd _build
	if [[ -z $EUPS_GITREV ]]; then
		# Download tarball from github
		curl -L $EUPS_TARURL | tar xzvf -
		cd eups-$EUPS_VERSION
	else
		# Clone from git repository
		git clone "$EUPS_GITREPO"
		cd eups
		git checkout $EUPS_GITREV
	fi
	
	./configure --prefix="$LSST_HOME"/eups --with-eups="$LSST_HOME" --with-python="$PYTHON"
	make install
	
	) > eupsbuild.log 2>&1 && echo " done." || { echo " FAILED."; echo "See log in eupsbuild.log"; exit -1; }
	
fi

##########	Source EUPS

set +e
source "$LSST_HOME/eups/bin/setups.sh"
set -e

##########	Download optional component (python, git, ...)

if true; then
	if [[ $WITH_GIT = 1 ]]; then
		echo "Installing git ... "
	eups distrib install --repository="$EUPS_PKGROOT" git
	setup git
	CMD_SETUP_GIT='setup git'
	fi
	
	if [[ $WITH_ANACONDA = 1 ]]; then
		echo "Installing Anaconda Python Distribution ... "
		eups distrib install --repository="$EUPS_PKGROOT" anaconda
		setup anaconda
		CMD_SETUP_ANACONDA='setup anaconda'
	fi
fi

##########	Install the Basic Environment

if true; then
	echo "Installing the basic environment ... "
	eups distrib install --repository="$EUPS_PKGROOT" lsst
fi

##########	Create the environment loader scripts

function generate_loader_bash() {
	file_name=$1
	cat > $file_name <<-EOF
		# This script is intended to be used with bash to load the minimal LSST environment
		# Usage: source $(basename $file_name)

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.sh"
		EUPS_PATH="\${LSST_HOME}"

		# Setup optional packages
		$CMD_SETUP_ANACONDA
		$CMD_SETUP_GIT

		# Setup LSST minimal environment
		setup lsst
EOF
}

function generate_loader_csh() {
	file_name=$1
	cat > $file_name <<-EOF
		# This script is intended to be used with (t)csh to load the minimal LSST environment
		# Usage: source $(basename $file_name)

		set sourced=(\$_)
		if ("\${sourced}" != "") then
		   # If not already initialized, set LSST_HOME to the directory where this script is located
		   set this_script = \${sourced[2]}
		   if ( ! \${?LSST_HOME} ) then
			  set LSST_HOME = \`dirname \${this_script}\`
			  set LSST_HOME = \`cd \${LSST_HOME} && pwd\`
		   endif

		   # Bootstrap EUPS
		   set EUPS_DIR = "\${LSST_HOME}/eups"
		   source "\${EUPS_DIR}/bin/setups.csh"
		   set EUPS_PATH = "\${LSST_HOME}"

		   # Setup optional packages
		   $CMD_SETUP_ANACONDA
		   $CMD_SETUP_GIT

		   # Setup LSST minimal environment
		   setup lsst
		endif
EOF
}

function generate_loader_ksh() {
	file_name=$1
	cat > $file_name <<-EOF
		# This script is intended to be used with ksh to load the minimal LSST environment
		# Usage: source $(basename $file_name)

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${.sh.file}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.sh"
		EUPS_PATH="\${LSST_HOME}"

		# Setup optional packages
		$CMD_SETUP_ANACONDA
		$CMD_SETUP_GIT

		# Setup LSST minimal environment
		setup lsst
EOF
}

function generate_loader_zsh() {
	file_name=$1
	cat > $file_name <<-EOF
		# This script is intended to be used with zsh to load the minimal LSST environment
		# Usage: source $(basename $file_name)

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [[ -z \${LSST_HOME} ]]; then
		   LSST_HOME="\$( cd "\$( dirname "\${0}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.zsh"
		EUPS_PATH="\${LSST_HOME}"

		# Setup optional packages
		$CMD_SETUP_ANACONDA
		$CMD_SETUP_GIT

		# Setup LSST minimal environment
		setup lsst
EOF
}

for sfx in bash ksh csh zsh; do
	echo -n "Creating startup scripts ($sfx) ... "
	generate_loader_$sfx $LSST_HOME/loadLSST.$sfx
	echo "done."
done

##########	Helpful message about what to do next

cat <<-EOF
	
	Bootstrap complete. To continue installing (and to use) the LSST stack
	type one of:

		source "$LSST_HOME/loadLSST.bash"  # for bash
		source "$LSST_HOME/loadLSST.csh"   # for csh
		source "$LSST_HOME/loadLSST.ksh"   # for ksh
		source "$LSST_HOME/loadLSST.zsh"   # for zsh

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
