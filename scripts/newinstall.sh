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
#	* Creating the loadLSST.xxx scripts
#

set -e

#
# Note to developers: change these when the EUPS version we use changes
#

EUPS_VERSION=${EUPS_VERSION:-2.1.3}

EUPS_GITREV=${EUPS_GITREV:-}
EUPS_GITREPO=${EUPS_GITREPO:-https://github.com/RobertLuptonTheGood/eups.git}
EUPS_TARURL=${EUPS_TARURL:-https://github.com/RobertLuptonTheGood/eups/archive/$EUPS_VERSION.tar.gz}

EUPS_PKGROOT_BASE_URL=${EUPS_PKGROOT_BASE_URL:-https://eups.lsst.codes/stack}
EUPS_USE_TARBALLS=${EUPS_USE_TARBALLS:-false}

# At the moment, we default to the -2 option and install Python 2 miniconda
# if we are asked to install a Python. Once the Python 3 port is stable
# we can switch the default or insist that the user specifies a version.
LSST_PYTHON_VERSION=${LSST_PYTHON_VERSION:-2}
MINICONDA_VERSION=${MINICONDA_VERSION:-4.2.12}
# this git ref controls which set of conda packages are used to initialize the
# the default conda env.
LSSTSW_REF=${LSSTSW_REF:-7c8e67}
MINICONDA_BASE_URL=${MINICONDA_BASE_URL:-https://repo.continuum.io/miniconda}
CONDA_CHANNELS=${CONDA_CHANNELS:-}

LSST_HOME="$PWD"

# the canonical source of this script
NEWINSTALL_URL="https://raw.githubusercontent.com/lsst/lsst/master/scripts/newinstall.sh"

#
# removing leading/trailing whitespace from a string
#
#http://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable#12973694
#
trim() {
	local var="$*"
	# remove leading whitespace characters
	var="${var#"${var%%[![:space:]]*}"}"
	# remove trailing whitespace characters
	var="${var%"${var##*[![:space:]]}"}"
	echo -n "$var"
}

print_error() {
	>&2 echo -e "$@"
}

fail() {
	local code=${2:-1}
	[[ -n $1 ]] && print_error "$1"
	# shellcheck disable=SC2086
	exit $code
}

usage() {
	fail "$(cat <<-EOF

		usage: newinstall.sh [-b] [-f] [-h] [-n] [-3|-2] [-t] [-P <path-to-python>]
		 -b -- Run in batch mode. Don\'t ask any questions and install all extra
		       packages.
		 -c -- Attempt to continue a previously failed install.
		 -n -- No-op. Go through the motions but echo commands instead of running
		       them.
		 -P [PATH_TO_PYTHON] -- Use a specific python interpreter for EUPS.
		 -2 -- Use Python 2 if the script is installing its own Python. (default)
		 -3 -- Use Python 3 if the script is installing its own Python.
		 -t -- Use pre-compiled EUPS "tarball" packages, if available.
		 -h -- Display this help message.

		EOF
	)"
}

miniconda_slug() {
	echo "miniconda${LSST_PYTHON_VERSION}-${MINICONDA_VERSION}"
}

python_env_slug() {
	echo "$(miniconda_slug)-${LSSTSW_REF}"
}

eups_slug() {
	local eups_slug=$EUPS_VERSION

	if [[ -n $EUPS_GITREV ]]; then
		eups_slug=$EUPS_GITREV
	fi

	echo "$eups_slug"
}

eups_base_dir() {
	echo "${LSST_HOME}/eups"
}

eups_dir() {
	echo "$(eups_base_dir)/$(eups_slug)"
}

#
# version the eups product installation path using the *complete* python
# environment
#
# XXX this will probably need to be extended to include the compiler used for
# binary tarballs
#
eups_path() {
	echo "${LSST_HOME}/stack/$(python_env_slug)"
}

parse_args() {
	local OPTIND
	local opt

	while getopts cbhnP:32t opt; do
		case $opt in
			b)
				BATCH_FLAG=true
				;;
			c)
				CONT_FLAG=true
				;;
			n)
				NOOP_FLAG=true
				;;
			P)
				EUPS_PYTHON=$OPTARG
				;;
			2)
				LSST_PYTHON_VERSION=2
				;;
			3)
				LSST_PYTHON_VERSION=3
				;;
			t)
				EUPS_USE_TARBALLS=true
				;;
			h|*)
				usage
				;;
		esac
	done
	shift $((OPTIND - 1))
}

#
# determine the osfamily and release string
#
# where osfamily is one of:
#   - redhat (includes centos & fedora)
#   - osx (Darwin)
#
# where release is:
#   - on osx, the release string is the complete version (Eg. 10.11.6)
#   - on redhat, the release string is only the major version number (Eg. 7)
#
# osfamily string is returned in the variable name passed as $1
# release string is returned in the variable name passed as $2
#
sys::osfamily() {
	local __osfamily_result=${1?osfamily result variable is required}
	local __release_result=${2?release result variable is required}
	local __debug=$3

	local __osfamily
	local __release

	case $(uname -s) in
		Linux*)
			local release_file='/etc/redhat-release'
			if [[ ! -e $release_file ]]; then
				[[ $__debug == true ]] && print_error "unknown osfamily"
			fi
			__osfamily="redhat"

			# capture only major version number because "posix character classes"
			if [[ ! $(<"$release_file") =~ release[[:space:]]*([[:digit:]]+) ]]; then
				[[ $__debug == true ]] && print_error "unable to find release string"
			fi
			__release="${BASH_REMATCH[1]}"
			;;
		Darwin*)
			__osfamily="osx"

			if ! release=$(sw_vers -productVersion); then
				[[ $__debug == true ]] && print_error "unable to find release string"
			fi
			__release=$(trim "$release")
			;;
		*)
			print_error "unknown osfamily"
			;;
	esac

	eval "$__osfamily_result=$__osfamily"
	eval "$__release_result=$__release"
}

#
# return a single string representation of a platform.
# Eg. el7
#
# XXX cc lookup should be a seperate function if/when there is more than one #
# compiler option per platform.
#
sys::platform() {
	local __osfamily=${1?osfamily is required}
	local __release=${2?release is required}
	local __platform_result=${3?platform result variable is required}
	local __target_cc_result=${4?target_cc result variable is required}
	local __debug=$5

	local __platform
	local __target_cc

	case $__osfamily in
		redhat)
			case $__release in
				6)
					__platform=el6
					__target_cc=devtoolset-3
					;;
				7)
					__platform=el7
					__target_cc=gcc-system
					;;
				*)
					[[ $__debug == true ]] && print_error "unsupported release: $__release"
					;;
			esac
			;;
		osx)
			case $__release in
				# XXX bash 3.2 on osx does not support case fall-through
				10.9.* | 10.1?.*)
					__platform=10.9
					__target_cc=clang-800.0.42.1
					;;
				*)
					[[ $__debug == true ]] && print_error "unsupported release: $__release"
					;;
			esac
			;;
		*)
			[[ $__debug == true ]] && print_error "unsupported osfamily: $__osfamily"
			;;
	esac

	eval "$__platform_result=$__platform"
	eval "$__target_cc_result=$__target_cc"
}

# http://stackoverflow.com/questions/1527049/join-elements-of-an-array#17841619
join() { local IFS="$1"; shift; echo "$*"; }

default_eups_pkgroot() {
	local use_tarballs=${1:-false}

	local osfamily
	local release
	local platform
	local target_cc
	declare -a roots

	local pyslug
	pyslug=$(python_env_slug)

	# only probe system *IF* tarballs are desired
	if [[ $use_tarballs == true ]]; then
		sys::osfamily osfamily release
	fi

	if [[ -n $osfamily && -n $release ]]; then
		sys::platform "$osfamily" "$release" platform target_cc
	fi

	if [[ -n $EUPS_PKGROOT_BASE_URL ]]; then
		if [[ -n $platform && -n $target_cc ]]; then
			# binary "tarball" pkgroot
			roots+=( "${EUPS_PKGROOT_BASE_URL}/${osfamily}/${platform}/${target_cc}/${pyslug}" )
		fi

		roots+=( "${EUPS_PKGROOT_BASE_URL}/src" )
	fi

	echo -n "$(join '|' "${roots[@]}")"
}

config_curl() {
	# Prefer system curl; user-installed ones sometimes behave oddly
	if [[ -x /usr/bin/curl ]]; then
		CURL=${CURL:-/usr/bin/curl}
	else
		CURL=${CURL:-curl}
	fi

	# disable curl progress meter unless running under a tty -- this is intended to
	# reduce the amount of console output when running under CI
	CURL_OPTS='-#'
	if [[ ! -t 1 ]]; then
		CURL_OPTS='-sS'
	fi
}

miniconda::install() {
	local py_ver=${1?python version is required}
	local mini_ver=${2?miniconda version is required}
	local prefix=${3?prefix is required}
	local miniconda_base_url=${4:-https://repo.continuum.io/miniconda}

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

	miniconda_file_name="Miniconda${py_ver}-${mini_ver}-${ana_platform}.sh"
	echo "::: Deploying ${miniconda_file_name}"

	(
		set -e

		# the miniconda installer seems to complains if the filename does not end
		# with .sh
		tmpfile=$(mktemp -t "XXXXXXXX.${miniconda_file_name}")
		# attempt to be a good citizen and not leave tmp files laying around
		# after either a normal exit or an error condition
		# shellcheck disable=SC2064
		trap "{ rm -rf $tmpfile; }" EXIT

		$cmd "$CURL" "$CURL_OPTS" -L \
			"${miniconda_base_url}/${miniconda_file_name}" \
			--output "$tmpfile"

		$cmd bash "$tmpfile" -b -p "$prefix"
	)
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
	local py_ver=${1?python version is required}
	local ref=${2?lsstsw git ref is required}

	case $(uname -s) in
		Linux*)
			conda_packages="conda${py_ver}_packages-linux-64.txt"
			;;
		Darwin*)
			conda_packages="conda${py_ver}_packages-osx-64.txt"
			;;
		*)
			fail "Cannot configure miniconda env: unsupported platform $(uname -s)"
			;;
	esac

	local baseurl="https://raw.githubusercontent.com/lsst/lsstsw/${ref}/etc/"
	local tmpfile

	# conda may leave behind lock files from an uncompleted package installation
	# attempt.  These need to be cleaned up before [re]attempting to install
	# packages.
	$cmd conda clean --lock

	(
		set -e

		# disable conda progress meter unless running under a tty -- this is
		# intended to reduce the amount of console output when running under CI
		if [[ ! -t 1 ]]; then
			conda_opts='--quiet'
	  fi

		tmpfile=$(mktemp -t "${conda_packages}.XXXXXXXX")
		# attempt to be a good citizen and not leave tmp files laying around
		# after either a normal exit or an error condition
		# shellcheck disable=SC2064
		trap "{ rm -rf $tmpfile; }" EXIT
		$cmd "$CURL" "$CURL_OPTS" \
			-L \
			"${baseurl}/${conda_packages}" \
			--output "$tmpfile"

		$cmd conda install --yes --file "$tmpfile" $conda_opts
	)
}

#
# Warn if there's a different version on the server
#
# Don't make this fatal, it should still work for developers who are hacking
# their copy.
#
# Don't attempt to run diff when the script has been piped into the shell
#
up2date_check() {
	set +e

	local amidiff
	amidiff=$($CURL "$CURL_OPTS" -L "$NEWINSTALL_URL" | diff --brief - "$0")

	if [[ $amidiff == *differ ]]; then
		print_error "$(cat <<-EOF
			!!! This script differs from the official version on the distribution
			server.  If this is not intentional, get the current version from here:
			${NEWINSTALL_URL}
			EOF
		)"
	fi

	set -e
}

# Discuss the state of Git.
git_check() {
	if hash git 2>/dev/null; then
		local gitvernum
		gitvernum=$(git --version | cut -d\  -f 3)

		local gitver
		# shellcheck disable=SC2046 disable=SC2183
		gitver=$(printf "%02d-%02d-%02d\n" \
			$(echo "$gitvernum" | cut -d. -f1-3 | tr . ' '))
	fi

	if [[ $gitver < 01-08-04 ]]; then
		if [[ $BATCH_FLAG != true ]]; then
			cat <<-EOF
			Detected $(git --version).

			The git version control system is frequently used with LSST software.
			While the LSST stack should build and work even in the absence of git, we
			don\'t regularly run and test it in such environments. We therefore
			recommend you have at least git 1.8.4 installed with your normal
			package manager.

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
}

#
#	Test/warn about Python versions, offer to get miniconda if not supported.
#	LSST currently mandates Python 3.5 and, optionally, 2.7.  We assume that the
#	python in PATH is the python that will be used to build the stack if
#	miniconda(2/3) is not installed.
#
python_check() {
	# Check the version by running a small Python program (taken from the Python
	# EUPS package) XXX this will break if python is not in $PATH
	local pyverok
	pyverok=$(python -c 'import sys
minver2=7
minver3=5
vmaj = sys.version_info[0]
vmin = sys.version_info[1]
if (vmaj == 2 and vmin >= minver2) or (vmaj == 3 and vmin >= minver3):
    print(1)
else:
    print(0)')
	if [[ $BATCH_FLAG = true ]]; then
		WITH_MINICONDA=true
	else
		if [[ $pyverok != 1 ]]; then
			cat <<-EOF

			LSST stack requires Python 2 (>=2.7) or 3 (>=3.5); you seem to have
			$(python -V 2>&1) on your path ($(which python)).  Please set up a
			compatible python interpreter, prepend it to your PATH, and rerun this
			script.  Alternatively, we can set up the Miniconda Python distribution

			for you.
			EOF
		fi

		cat <<-EOF

		In addition to Python 2 (>=2.7) or 3 (>=3.5), some LSST packages depend on
		recent versions of numpy, matplotlib, and scipy.  If you do not have all of
		these, the installation may fail.  Using the Miniconda Python distribution
		will ensure all these are set up.

		Miniconda Python installed by this installer will be managed by LSST\'s EUPS
		package manager, and will not replace or modify your system python.

		EOF

		while true; do
		read -r -p "$(cat <<-EOF
			Would you like us to install the Miniconda Python distribution (if
			unsure, say yes)? 
			EOF
		)" yn

		case $yn in
			[Yy]* )
				WITH_MINICONDA=true
				break
				;;
			[Nn]* )
				if [[ $pyverok != 1 ]]; then
					cat <<-EOF

					Thanks. After you install Python 2.7 or 3.5 and the required modules,
					rerun this script to continue the installation.

					EOF
					exit
				fi
				break;
				;;
			* ) echo "Please answer yes or no.";;
		esac
		done
		echo
	fi
}

bootstrap_miniconda() {
	local miniconda_base_path="${LSST_HOME}/python"
	local miniconda_path
	miniconda_path="${miniconda_base_path}/$(miniconda_slug)"

	local miniconda_path_old
	miniconda_path_old="${LSST_HOME}/$(miniconda_slug)"

	# remove old unnested miniconda -- the install has hard coded shebangs
	if [[ -e $miniconda_path_old ]]; then
		rm -rf "$miniconda_path_old"
	fi

	if [[ ! -e $miniconda_path ]]; then
		miniconda::install \
			"$LSST_PYTHON_VERSION" \
			"$MINICONDA_VERSION" \
			"$miniconda_path" \
			"$MINICONDA_BASE_URL"
	fi

	export PATH="${miniconda_path}/bin:${PATH}"

	if [[ -n $CONDA_CHANNELS ]]; then
		miniconda::config_channels "$CONDA_CHANNELS"
	fi
	miniconda::lsst_env "$LSST_PYTHON_VERSION" "$LSSTSW_REF"

	CMD_SETUP_MINICONDA_SH="export PATH=\"${miniconda_path}/bin:\${PATH}\""
	CMD_SETUP_MINICONDA_CSH="setenv PATH ${miniconda_path}/bin:\$PATH"
}

#
# $EUPS_PYTHON is the Python used to install/run EUPS.  It can be any Python >=
# v2.6
#
install_eups() {
	if [[ ! -x $EUPS_PYTHON ]]; then
		fail "$(cat <<-EOF
			Cannot find or execute \'${EUPS_PYTHON}\'.  Please set the EUPS_PYTHON
			environment variable or use the -P option to point to a functioning
			Python >= 2.6 interpreter and rerun.
			EOF
		)"
	fi

	local pyverok
	pyverok=$($EUPS_PYTHON -c 'import sys; print("%i" % (sys.hexversion >= 0x02060000))')
	if [[ $pyverok != 1 ]]; then
		fail "$(cat <<-EOF
			EUPS requires Python 2.6 or newer; we are using $("$EUPS_PYTHON" -V 2>&1)
			from ${EUPS_PYTHON}.  Please set up a compatible python interpreter using
			the EUPS_PYTHON environment variable or the -P command line option.
			EOF
		)"
	fi

	if [[ $EUPS_PYTHON != /usr/bin/python ]]; then
		echo "Using python at ${EUPS_PYTHON} to install EUPS"
	fi

	# if there is an existing, unversioned install, renamed it to "legacy"
	if [[ -e "$(eups_base_dir)/Release_Notes" ]]; then
		local eups_legacy_dir
		eups_legacy_dir="$(eups_base_dir)/legacy"
		local eups_tmp_dir="${LSST_HOME}/eups-tmp"

		echo "Moving old EUPS to ${eups_legacy_dir}"

		mv "$(eups_base_dir)" "$eups_tmp_dir"
		mkdir -p "$(eups_base_dir)"
		mv "$eups_tmp_dir" "$eups_legacy_dir"
	fi

	echo -n "Installing EUPS ($(eups_slug))... "

	# remove previous install
	if [[ -e $(eups_dir) ]]; then
		chmod -R +w "$(eups_dir)"
		rm -rf "$(eups_dir)"
	fi

	local eups_build_dir="$LSST_HOME/_build"

	if ! ( set -e
		mkdir "$eups_build_dir"
		cd "$eups_build_dir"

		if [[ -z $EUPS_GITREV ]]; then
			# Download tarball from github
			$cmd "$CURL" "$CURL_OPTS" -L "$EUPS_TARURL" | tar xzvf -
			$cmd cd "eups-${EUPS_VERSION}"
		else
			# Clone from git repository
			$cmd git clone "$EUPS_GITREPO" eups
			$cmd cd eups
			$cmd git checkout "$EUPS_GITREV"
		fi

		$cmd ./configure \
			--prefix="$(eups_dir)" \
			--with-eups="$(eups_path)" \
			--with-python="$EUPS_PYTHON"
		$cmd make install
	) > eupsbuild.log 2>&1 ; then
		fail "$(cat <<-EOF
			FAILED.
			fail "See log in eupsbuild.log"
			EOF
		)"
	fi

	# update current eups version link
	local eups_current_link
	eups_current_link="$(eups_base_dir)/current"

	if [[ $(readlink "$eups_current_link") != $(eups_slug) ]]; then
		ln -sf "$(eups_dir)" "$eups_current_link"
	fi

	echo " done."
}

generate_loader_bash() {
	local file_name=$1

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with bash to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		# Setup optional packages
		${CMD_SETUP_MINICONDA_SH}

		# If not already initialized, set LSST_HOME to the directory where this
		# script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups/$(eups_slug)"
		source "\${EUPS_DIR}/bin/setups.sh"

		export EUPS_PKGROOT=\${EUPS_PKGROOT:-$EUPS_PKGROOT}
	EOF
}

generate_loader_csh() {
	local file_name=$1

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with (t)csh to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		# Setup optional packages
		${CMD_SETUP_MINICONDA_CSH}

		# If not already initialized, set LSST_HOME to the directory where this
		# script is located
		if ( ! \${?LSST_HOME} ) then
		  set LSST_HOME = \`dirname \$0\`
		  set LSST_HOME = \`cd \${LSST_HOME} && pwd\`
		endif

		# Bootstrap EUPS
		set EUPS_DIR = "\${LSST_HOME}/eups"
		source "\${EUPS_DIR}/bin/setups.csh"

		if ( ! \${?EUPS_PKGROOT} ) then
		  setenv EUPS_PKGROOT "$EUPS_PKGROOT"
		endif
	EOF
}

generate_loader_ksh() {
	local file_name=$1

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with ksh to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		# Setup optional packages
		${CMD_SETUP_MINICONDA_SH}

		# If not already initialized, set LSST_HOME to the directory where this
		# script is located
		if [ "x\${LSST_HOME}" = "x" ]; then
		   LSST_HOME="\$( cd "\$( dirname "\${.sh.file}" )" && pwd )"
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups/$(eups_slug)"
		source "\${EUPS_DIR}/bin/setups.sh"

		export EUPS_PKGROOT=\${EUPS_PKGROOT:-$EUPS_PKGROOT}
	EOF
}

generate_loader_zsh() {
	local file_name=$1

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with zsh to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		# Setup optional packages
		${CMD_SETUP_MINICONDA_SH}

		# If not already initialized, set LSST_HOME to the directory where this
		# script is located
		if [[ -z \${LSST_HOME} ]]; then
		   LSST_HOME=\`dirname "\$0:A"\`
		fi

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups/$(eups_slug)"
		source "\${EUPS_DIR}/bin/setups.zsh"

		export EUPS_PKGROOT=\${EUPS_PKGROOT:-$EUPS_PKGROOT}
	EOF
}

create_load_scripts() {
	for sfx in bash ksh csh zsh; do
		echo -n "Creating startup scripts (${sfx}) ... "
		generate_loader_$sfx "${LSST_HOME}/loadLSST.${sfx}"
		echo "done."
	done
}

print_greeting() {
	cat <<-EOF

		Bootstrap complete. To continue installing (and to use) the LSST stack type
		one of:

			source "${LSST_HOME}/loadLSST.bash"  # for bash
			source "${LSST_HOME}/loadLSST.csh"   # for csh
			source "${LSST_HOME}/loadLSST.ksh"   # for ksh
			source "${LSST_HOME}/loadLSST.zsh"   # for zsh

		Individual LSST packages may now be installed with the usual \`eups distrib
		install\` command.  For example, to install the science pipeline elements
		of the LSST stack, use:

			eups distrib install lsst_apps

		Next, read the documentation at:

			https://pipelines.lsst.io

		and feel free to ask any questions via the LSST Community forum:

			https://community.lsst.org/c/support

	                                       Thanks!
	                                                -- The LSST Software Teams
	                                                       http://dm.lsst.org/

	EOF
}

#
# test to see if script is being sourced or executed. Note that this function
# will work correctly when the source is being piped to a shell. `Ie., cat
# newinstall.sh | bash -s`
#
# See: https://stackoverflow.com/a/12396228
#
am_I_sourced() {
	if [ "${FUNCNAME[1]}" = source ]; then
		return 0
	else
		return 1
	fi
}


#
# script main
#
main() {
	config_curl

	CONT_FLAG=false
	BATCH_FLAG=false
	NOOP_FLAG=false

	parse_args "$@"

	cat <<-EOF

		LSST Software Stack Builder
		=======================================================================

	EOF

	# If no-op, prefix every install command with echo
	if [[ $NOOP_FLAG == true ]]; then
		cmd="echo"
		echo "!!! -n flag specified, no install commands will be really executed"
	else
		cmd=""
	fi

	# Refuse to run from a non-empty directory
	if [[ $CONT_FLAG == false ]]; then
		if [[ ! -z $(ls) && ! $(ls) == newinstall.sh ]]; then
			fail "$(cat <<-EOF
				Please run this script from an empty directory. The LSST stack will be
				installed into it.
				EOF
			)"
		fi
	fi

	# Warn if there's a different version on the server
	if [[ -n $0 && $0 != bash ]]; then
		up2date_check
	fi

	git_check
	python_check

	# By default we use the PATH Python to bootstrap EUPS.  Set $EUPS_PYTHON to
	# override this or use the -P command line option.  $EUPS_PYTHON is used to
	# install and run EUPS and will not necessarily be the python in the path being
	# used to build the stack itself.
	EUPS_PYTHON=${EUPS_PYTHON:-$(which python)}

	EUPS_PKGROOT=${EUPS_PKGROOT:-$(default_eups_pkgroot $EUPS_USE_TARBALLS)}
	print_error "Configured EUPS_PKGROOT: ${EUPS_PKGROOT}"

	# Bootstrap miniconda (optional)
	if [[ $WITH_MINICONDA == true ]]; then
		bootstrap_miniconda
	fi

	# Install EUPS
	install_eups

	# Create the environment loader scripts
	create_load_scripts

	# Helpful message about what to do next
	print_greeting
}

#
# support being sourced as a lib or executed
#
if ! am_I_sourced; then
	main "$@"
fi

# vim: tabstop=2 shiftwidth=2 noexpandtab
