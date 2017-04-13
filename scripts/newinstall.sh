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
#	* Installing Miniconda2 Python distribution, if necessary
#	* Installing EUPS
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

MINICONDA_VERSION=${MINICONDA_VERSION:-4.2.12}
# this git ref controls which set of conda packages are used to initialize the
# the default conda env.
LSSTSW_REF=${LSSTSW_REF:-7c8e67}
MINICONDA_BASE_URL=${MINICONDA_BASE_URL:-https://repo.continuum.io/miniconda}
CONDA_CHANNELS=${CONDA_CHANNELS:-}

LSST_HOME="$PWD"

NEWINSTALL="newinstall.sh" # the canonical name of this file on the server

# Prefer system curl; user-installed ones sometimes behave oddly
if [[ -x /usr/bin/curl ]]; then
	CURL=${CURL:-/usr/bin/curl}
else
	CURL=${CURL:-curl}
fi

print_error() {
	>&2 echo -e "$@"
}

fail() {
	code=${2:1}
	print_error "$1"
	# shellcheck disable=SC2086
	exit $code
}

miniconda::install() {
	local python_version=$1
	local version=$2
	local prefix=$3
	local miniconda_base_url=${4:-https://repo.continuum.io/miniconda}

	[[ -z $python_version ]] && fail "python_version param is required"
	[[ -z $version ]] && fail "version param is required"
	[[ -z $prefix ]] && fail "prefix param is required"

	case $(uname -s) in
		Linux*)
			ana_platform="Linux-x86_64"
			;;
		Darwin*)
			ana_platform="MacOSX-x86_64"
			;;
		*)
			fail "Cannot install miniconda: unsupported platform $(uname -s)"
			;;
	esac

	miniconda_file_name="Miniconda${python_version}-${version}-${ana_platform}.sh"
	echo "::: Deploying ${miniconda_file_name}"
	$cmd "$CURL" -# -L -O "${miniconda_base_url}/${miniconda_file_name}"

	$cmd bash "$miniconda_file_name" -b -p "$prefix"
}

# configure alt conda channel(s)
miniconda::config_channels() {
	local channels=$1

	[[ -z $channels ]] && fail "channels param is required"

	# remove any previously configured non-default channels
	# XXX allowed to fail
	set +e
	$cmd conda config --remove-key channels
	set -e

	for c in $channels; do
		$cmd conda config --add channels "$c"
	done

	# remove the default channels
	$cmd conda config --remove channels defaults

	$cmd conda config --show
}

# Install packages on which the stack is known to depend
miniconda::lsst_env() {
	local python_version=$1
	local ref=$2

	[[ -z $python_version ]] && fail "python_version param is required"
	[[ -z $ref ]] && fail "ref param is required"

	case $(uname -s) in
		Linux*)
			conda_packages="conda${python_version}_packages-linux-64.txt"
			;;
		Darwin*)
			conda_packages="conda${python_version}_packages-osx-64.txt"
			;;
		*)
			fail "Cannot configure miniconda env: unsupported platform $(uname -s)"
			;;
	esac

	local baseurl="https://raw.githubusercontent.com/lsst/lsstsw/${ref}/etc/"
	local tmpfile

	(
		tmpfile=$(mktemp -t "${conda_packages}.XXXXXXXX")
		# attempt to be a good citizen and not leave tmp files laying around
		# after either a normal exit or an error condition
		# shellcheck disable=SC2064
		trap "{ rm -rf $tmpfile; }" EXIT
		$cmd "$CURL" -# -L --silent "${baseurl}/${conda_packages}" --output "$tmpfile"

		$cmd conda install --yes --file "$tmpfile"
	)
}

cont_flag=false
batch_flag=false
help_flag=false
noop_flag=false

# At the moment, we default to the -2 option and install Python 2 miniconda
# if we are asked to install a Python. Once the Python 3 port is stable
# we can switch the default or insist that the user specifies a version.
PYTHON_VERSION=2

while getopts cbhnP:32 optflag; do
	case $optflag in
		b)
			batch_flag=true
			;;
		c)
			cont_flag=true
			;;
		n)
			noop_flag=true
			;;
		P)
			EUPS_PYTHON=$OPTARG
			;;
		2)
			PYTHON_VERSION=2
			;;
		3)
			PYTHON_VERSION=3
			;;
		h)
			help_flag=true
			;;
	esac
done

shift $((OPTIND - 1))

if [[ "$help_flag" = true ]]; then
	print_error
	print_error "usage: newinstall.sh [-b] [-f] [-h] [-n] [-3|-2] [-P <path-to-python>]"
	print_error " -b -- Run in batch mode.	Don't ask any questions and install all extra packages."
	print_error " -c -- Attempt to continue a previously failed install."
	print_error " -n -- No-op. Go through the motions but echo commands instead of running them."
	print_error " -P [PATH_TO_PYTHON] -- Use a specific python interpreter for EUPS."
	print_error " -2 -- Use Python 2 if the script is installing its own Python. (default)"
	print_error " -3 -- Use Python 3 if the script is installing its own Python."
	print_error " -h -- Display this help message."
	print_error
	fail
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
	print_error "!!! This script differs from the official version on the distribution server."
	print_error "    If this is not intentional, get the current version from here:"
	print_error "    $EUPS_PKGROOT/$NEWINSTALL"
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
		fail "Please run this script from an empty directory. The LSST stack will be installed into it."
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
						exit
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
		WITH_MINICONDA=true
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
				WITH_MINICONDA=true
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

##########	Bootstrap miniconda (optional)

if true; then
	if [[ $WITH_MINICONDA == true ]]; then
		miniconda_path="${LSST_HOME}/miniconda${PYTHON_VERSION}-${MINICONDA_VERSION}"
		if [[ ! -e $miniconda_path ]]; then
			miniconda::install \
				"$PYTHON_VERSION" \
				"$MINICONDA_VERSION" \
				"$miniconda_path" \
				"$MINICONDA_BASE_URL"
		fi

		export PATH="${miniconda_path}/bin:${PATH}"

		if [[ -n $CONDA_CHANNELS ]]; then
			miniconda::config_channels "$CONDA_CHANNELS"
		fi
		miniconda::lsst_env "${PYTHON_VERSION}" "${LSSTSW_REF}"

		CMD_SETUP_MINICONDA_SH="export PATH=\"${miniconda_path}/bin:\${PATH}\""
		CMD_SETUP_MINICONDA_CSH="setenv PATH ${miniconda_path}/bin:\$PATH)"
	fi
fi

# By default we use the PATH Python to bootstrap EUPS.
# Set $EUPS_PYTHON to override this or use the -P command line option.
# $EUPS_PYTHON is used to install and run EUPS and will not necessarily
# be the python in the path being used to build the stack itself.
EUPS_PYTHON="${EUPS_PYTHON:-$(which python)}"


##########	Install EUPS

##########	$EUPS_PYTHON is the Python used to install/run EUPS.
##########	It can be any Python >= v2.6

if true; then
	if [[ ! -x "$EUPS_PYTHON" ]]; then
		fail "$(cat <<-EOF
			Cannot find or execute '$EUPS_PYTHON'.  Please set the EUPS_PYTHON
			environment variable or use the -P option to point to a functioning
			Python >= 2.6 interpreter and rerun.
			EOF
		)"
	fi

	PYVEROK=$($EUPS_PYTHON -c 'import sys; print("%i" % (sys.hexversion >= 0x02060000))')
	if [[ $PYVEROK != 1 ]]; then
		fail "$(cat <<-EOF
			EUPS requires Python 2.6 or newer; we are using $($EUPS_PYTHON -V 2>&1)
			from $EUPS_PYTHON.  Please set up a compatible python interpreter using
			the EUPS_PYTHON environment variable or the -P command line option.
			EOF
		)"
	fi

	if [[ $EUPS_PYTHON != /usr/bin/python ]]; then
		echo "Using python at ${EUPS_PYTHON} to install EUPS"
	fi

	if [[ -z $EUPS_GITREV ]]; then
		echo -n "Installing EUPS (v$EUPS_VERSION)... "
	else
		echo -n "Installing EUPS (branch $EUPS_GITREV from $EUPS_GITREPO)..."
	fi

	if ! (
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

		$cmd ./configure --prefix="$LSST_HOME"/eups --with-eups="$LSST_HOME" --with-python="$EUPS_PYTHON"
		$cmd make install
	) > eupsbuild.log 2>&1 ; then
		fail "$(cat <<-EOF
			FAILED.
			fail "See log in eupsbuild.log"
			EOF
		)"
	fi
	echo " done."

fi

##########	Source EUPS

set +e
$cmd source "$LSST_HOME/eups/bin/setups.sh"
set -e

##########	Download optional component (python, git, ...)


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

		# Setup optional packages
		$CMD_SETUP_MINICONDA_SH

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.sh"

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

		# Setup optional packages
		$CMD_SETUP_MINICONDA_CSH

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

		# Setup optional packages
		$CMD_SETUP_MINICONDA_SH

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${.sh.file}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.sh"

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

		# Setup optional packages
		$CMD_SETUP_MINICONDA_SH

		# If not already initialized, set LSST_HOME to the directory where this script is located
		if [[ -z \${LSST_HOME} ]]; then
		   LSST_HOME=\`dirname "\$0:A"\`
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.zsh"

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
	distrib install\` command.  For example, to install the science pipeline
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

# vim: tabstop=2 shiftwidth=2 noexpandtab
