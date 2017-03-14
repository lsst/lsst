#!/bin/bash

# Please preserve tabs as indenting whitespace at Mario's request
# to keep heredocs nice (--fe)
# Use 4-character tabs to match python indent look
#
# **** This file should not be edited in place ****
# It is maintained in a repository at
# git@github.com:lsst/lsst.git
#
# If the file must be modified, clone the repository
# and edit there.
# *************************************************
#
# Bootstrap lsst stack install by:
#	* Installing EUPS
#	* Installing Miniconda2 Python distribution, if necessary
#	* Install everything up to the lsst package
#	* Creating the loadLSST.xxx scripts
#

set -e

#
# Note to developers: change these when the EUPS version we use changes
#

EUPS_VERSION=${EUPS_VERSION:-2.1.2}

EUPS_GITREV=${EUPS_GITREV:-""}
EUPS_GITREPO=${EUPS_GITREPO:-"https://github.com/RobertLuptonTheGood/eups.git"}
EUPS_TARURL=${EUPS_TARURL:-"https://github.com/RobertLuptonTheGood/eups/archive/$EUPS_VERSION.tar.gz"}

EUPS_PKGROOT=${EUPS_PKGROOT:-"http://sw.lsstcorp.org/eupspkg"}

MINICONDA2_VERSION=${MINICONDA2_VERSION:-4.2.12.lsst1}
MINICONDA3_VERSION=${MINICONDA3_VERSION:-4.2.12.lsst1}

LSST_HOME="$PWD"

NEWINSTALL="newinstall.sh" # the canonical name of this file on the server

# Prefer system curl; user-installed ones sometimes behave oddly
if [[ -x /usr/bin/curl ]]; then
	CURL=${CURL:-/usr/bin/curl}
else
	CURL=${CURL:-curl}
fi

cont_flag=false
batch_flag=false
help_flag=false
noop_flag=false

# By default we use the PATH Python to bootstrap EUPS.
# Set $PYTHON to override this or use the -P command line option.
# $PYTHON is used to install and run EUPS and will not necessarily
# be the python in the path being used to build the stack itself.
PYTHON="${PYTHON:-$(which python)}"

# At the moment, we default to the -2 option and install Python 2 miniconda
# if we are asked to install a Python. Once the Python 3 port is stable
# we can switch the default or insist that the user specifies a version.
USE_PYTHON2=true

while getopts cbhnP:32 optflag; do
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
		n)
			noop_flag=true
			;;
		P)
			PYTHON=$OPTARG
			;;
		3)
			USE_PYTHON2=false
			;;
		2)
			USE_PYTHON2=true
			;;
	esac
done

shift $((OPTIND - 1))

if [[ "$help_flag" = true ]]; then
	echo
	echo "usage: newinstall.sh [-b] [-f] [-h] [-n] [-3|-2] [-P <path-to-python>]"
	echo " -b -- Run in batch mode.	Don't ask any questions and install all extra packages."
	echo " -c -- Attempt to continue a previously failed install."
	echo " -h -- Display this help message."
	echo " -n -- No-op. Go through the motions but echo commands instead of running them."
	echo " -3 -- Use Python 3 if the script is installing its own Python."
	echo " -2 -- Use Python 2 if the script is installing its own Python. (default)"
	echo " -P [PATH_TO_PYTHON] -- Use a specific python to bootstrap the stack."
	echo
	exit 0
fi

echo
echo "LSST Software Stack Builder"
echo "======================================================================="
echo

##########	Warn if there's a different version on the server

# Don't make this fatal, it should still work for developers who are hacking their copy.

set +e

AMIDIFF=$($CURL -L --silent "$EUPS_PKGROOT/$NEWINSTALL" | diff --brief - "$0")

if [[ $AMIDIFF = *differ ]]; then
	echo "!!! This script differs from the official version on the distribution server."
	echo "    If this is not intentional, get the current version from here:"
	echo "    $EUPS_PKGROOT/$NEWINSTALL"
fi

set -e

##########	If no-op, prefix every install command with echo

if [[ "$noop_flag" = true ]]; then
	cmd="echo"
	echo "!!! -n flag specified, no install commands will be really executed"
else
	cmd=""
fi

##########	Refuse to run from a non-empty directory

if [[ "$cont_flag" = false ]]; then
	if [[ ! -z "$(ls)" && ! "$(ls)" == "newinstall.sh" ]]; then
		echo "Please run this script from an empty directory. The LSST stack will be installed into it."
		exit -1;
	fi
fi

##########  Discuss the state of Git.

if true; then
	if hash git 2>/dev/null; then
		GITVERNUM=$(git --version | cut -d\  -f 3)
		# shellcheck disable=SC2046 disable=SC2183
		GITVER=$(printf "%02d-%02d-%02d\n" $(echo "$GITVERNUM" | cut -d. -f1-3 | tr . ' '))
	fi

	if [[ $GITVER < "01-08-04" ]]; then
		if [[ "$batch_flag" != true ]]; then
			cat <<-EOF
			Detected $(git --version).

			The git version control system is frequently used with LSST software. While
			the LSST stack should build and work even in the absence of git, we don't
			regularly run and test it in such environments. We therefore recommend you
			have at least git 1.8.4 installed with your normal package manager.

			EOF

			while true; do
				read -r -p "Would you like to try continuing without git? " yn
				case $yn in
					[Yy]* )
						echo "Continuing without git"
						break
						;;
					[Nn]* )
						echo "Okay install git and rerun the script."
						exit;
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


##########	Test/warn about Python versions, offer to get miniconda if not supported.
##########	LSST currently mandates Python 3.5 and, optionally, 2.7.
##########	We assume that the python in PATH is the python that will be used to
##########	build the stack if miniconda(2/3) is not installed.

if true; then
	# Check the version by running a small Python program (taken from the Python EUPS package)
	# XXX this will break if python is not in $PATH
	PYVEROK=$(python -c 'import sys
minver2=7
minver3=5
vmaj = sys.version_info[0]
vmin = sys.version_info[1]
if (vmaj == 2 and vmin >= minver2) or (vmaj == 3 and vmin >= minver3):
    print(1)
else:
    print(0)')
	if [[ "$batch_flag" = true ]]; then
		WITH_MINICONDA=1
	else
		if [[ $PYVEROK != 1 ]]; then
			cat <<-EOF

			LSST stack requires Python 2 (>=2.7) or 3 (>=3.5); you seem to have $(python -V 2>&1) on your
			path ($(which python)).	 Please set up a compatible python interpreter,
			prepend it to your PATH, and rerun this script.	 Alternatively, we can set
			up the Miniconda Python distribution for you.
			EOF
		fi

		cat <<-EOF

		In addition to Python 2 (>=2.7) or 3 (>=3.5), some LSST packages depend on recent versions of numpy,
		matplotlib, and scipy. If you don't have all of these, the installation may fail.
		Using the Miniconda Python distribution will ensure all these are set up.

		Miniconda Python installed by this installer will be managed by LSST's EUPS
		package manager, and will not replace or modify your system python.

		EOF

		while true; do
		read -r -p "Would you like us to install the Miniconda Python distribution (if unsure, say yes)? " yn
		case $yn in
			[Yy]* )
				WITH_MINICONDA=1
				break
				;;
			[Nn]* )
				if [[ $PYVEROK != 1 ]]; then
			echo
			echo "Thanks. After you install Python 2.7 or 3.5 and the required modules, rerun this script to"
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

##########	$PYTHON is the Python used to install/run EUPS.
##########	It can be any Python >= v2.6

if true; then
	if [[ ! -x "$PYTHON" ]]; then
		echo -n "Cannot find or execute '$PYTHON'. Please set the PYTHON environment variable or use the -P"
		echo " option to point to a functioning Python >= 2.6 interpreter and rerun."
		exit -1;
	fi

	PYVEROK=$($PYTHON -c 'import sys; print("%i" % (sys.hexversion >= 0x02060000))')
	if [[ $PYVEROK != 1 ]]; then
		cat <<-EOF

    EUPS requires Python 2.6 or newer; we are using $($PYTHON -V 2>&1) from
    $PYTHON.  Please set up a compatible python interpreter using the PYTHON
    environment variable or the -P command line option.
		EOF
		exit -1
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
			$cmd "$CURL" -L "$EUPS_TARURL" | tar xzvf -
			$cmd cd "eups-$EUPS_VERSION"
		else
			# Clone from git repository
			$cmd git clone "$EUPS_GITREPO"
			$cmd cd eups
			$cmd git checkout "$EUPS_GITREV"
		fi

		$cmd ./configure --prefix="$LSST_HOME"/eups --with-eups="$LSST_HOME" --with-python="$PYTHON"
		$cmd make install

	) > eupsbuild.log 2>&1
    # shellcheck disable=SC2181
    if [[ $? == 0 ]]; then
        echo " done."
    else
        { echo " FAILED."; echo "See log in eupsbuild.log"; exit -1; }
    fi

fi

##########	Source EUPS

set +e
$cmd source "$LSST_HOME/eups/bin/setups.sh"
set -e

##########	Download optional component (python, git, ...)

if true; then
	if [[ $WITH_MINICONDA == 1 ]]; then
		if [[ $USE_PYTHON2 == false ]]; then
			PYVER_SUFFIX=3
			MINICONDA_VERSION=${MINICONDA3_VERSION}
		else
			PYVER_SUFFIX=2
			MINICONDA_VERSION=${MINICONDA2_VERSION}
		fi
		echo "Installing Miniconda${PYVER_SUFFIX} Python Distribution ... "
		$cmd eups distrib install --repository="$EUPS_PKGROOT" "miniconda${PYVER_SUFFIX}" "$MINICONDA_VERSION"
		$cmd setup "miniconda${PYVER_SUFFIX}"
		CMD_SETUP_MINICONDA="setup miniconda${PYVER_SUFFIX}"
	fi
fi

##########	Install the Basic Environment

if true; then
	echo "Installing the basic environment ... "
	$cmd eups distrib install --repository="$EUPS_PKGROOT" lsst
fi

##########	Create the environment loader scripts

function generate_loader_bash() {
	file_name=$1
    # shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with bash to load the minimal LSST environment
		# Usage: source $(basename "$file_name")

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.sh"

		# Setup optional packages
		$CMD_SETUP_MINICONDA
		$CMD_SETUP_GIT

		# Setup LSST minimal environment
		setup lsst
EOF
}

function generate_loader_csh() {
	file_name=$1
    # shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with (t)csh to load the minimal LSST environment
		# Usage: source $(basename "$file_name")

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

		   # Setup optional packages
		   $CMD_SETUP_MINICONDA
		   $CMD_SETUP_GIT

		   # Setup LSST minimal environment
		   setup lsst
		endif
EOF
}

function generate_loader_ksh() {
	file_name=$1
    # shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with ksh to load the minimal LSST environment
		# Usage: source $(basename "$file_name")

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${.sh.file}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.sh"

		# Setup optional packages
		$CMD_SETUP_MINICONDA
		$CMD_SETUP_GIT

		# Setup LSST minimal environment
		setup lsst
EOF
}

function generate_loader_zsh() {
	file_name=$1
    # shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with zsh to load the minimal LSST environment
		# Usage: source $(basename "$file_name")

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [[ -z \${LSST_HOME} ]]; then
		   LSST_HOME=\`dirname "\$0:A"\`
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.zsh"

		# Setup optional packages
		$CMD_SETUP_MINICONDA
		$CMD_SETUP_GIT

		# Setup LSST minimal environment
		setup lsst
EOF
}

for sfx in bash ksh csh zsh; do
	echo -n "Creating startup scripts ($sfx) ... "
	generate_loader_$sfx "$LSST_HOME/loadLSST.$sfx"
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

		https://pipelines.lsst.io

	and feel free to ask any questions via the LSST Community forum:

		https://community.lsst.org/c/support

	                                       Thanks!
	                                                -- The LSST Software Teams
	                                                       http://dm.lsst.org/

EOF
