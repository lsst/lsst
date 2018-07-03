#!/bin/bash

# Please preserve tabs as indenting whitespace at Mario's request
# to keep heredocs nice (--fe)
#
# Bootstrap lsst stack install by:
#	* Installing Miniconda Python distribution, if necessary
#	* Installing EUPS
#	* Creating the loadLSST.xxx scripts
#

set -Eeo pipefail

#
# Note to developers: change these when the EUPS version we use changes
#

LSST_EUPS_VERSION=${LSST_EUPS_VERSION:-2.1.4}

LSST_EUPS_GITREV=${LSST_EUPS_GITREV:-}
LSST_EUPS_GITREPO=${LSST_EUPS_GITREPO:-https://github.com/RobertLuptonTheGood/eups.git}
LSST_EUPS_TARURL=${LSST_EUPS_TARURL:-https://github.com/RobertLuptonTheGood/eups/archive/${LSST_EUPS_VERSION}.tar.gz}

LSST_EUPS_PKGROOT_BASE_URL=${LSST_EUPS_PKGROOT_BASE_URL:-https://eups.lsst.codes/stack}
LSST_EUPS_USE_TARBALLS=${LSST_EUPS_USE_TARBALLS:-false}
LSST_EUPS_USE_EUPSPKG=${LSST_EUPS_USE_EUPSPKG:-true}

# force Python 3
LSST_PYTHON_VERSION=3
LSST_MINICONDA_VERSION=${LSST_MINICONDA_VERSION:-4.5.4}
# this git ref controls which set of conda packages are used to initialize the
# the default conda env.
LSST_LSSTSW_REF=${LSST_LSSTSW_REF:-10a4fa6}
LSST_MINICONDA_BASE_URL=${LSST_MINICONDA_BASE_URL:-https://repo.continuum.io/miniconda}
LSST_CONDA_CHANNELS=${LSST_CONDA_CHANNELS:-}
LSST_CONDA_ENV_NAME=${LSST_CONDA_ENV_NAME:-lsst-scipipe-${LSST_LSSTSW_REF}}

LSST_HOME="$PWD"

# the canonical source of this script
NEWINSTALL_URL="https://raw.githubusercontent.com/lsst/lsst/master/scripts/newinstall.sh"

#
# removing leading/trailing whitespace from a string
#
#http://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable#12973694
#
n8l::trim() {
	local var="$*"
	# remove leading whitespace characters
	var="${var#"${var%%[![:space:]]*}"}"
	# remove trailing whitespace characters
	var="${var%"${var##*[![:space:]]}"}"
	echo -n "$var"
}

n8l::print_error() {
	>&2 echo -e "$@"
}

n8l::fail() {
	local code=${2:-1}
	[[ -n $1 ]] && n8l::print_error "$1"
	# shellcheck disable=SC2086
	exit $code
}

#
# create/update a *relative* symlink, in the basedir of the target. An existing
# file or directory will be *stomped on*.
#
n8l::ln_rel() {
	local link_target=${1?link target is required}
	local link_name=${2?link name is required}

	target_dir=$(dirname "$link_target")
	target_name=$(basename "$link_target")

	( set -e
		cd "$target_dir"

		if [[ $(readlink "$target_name") != "$link_name" ]]; then
			# at least "ln (GNU coreutils) 8.25" will not change an abs symlink to be
			# rel, even with `-f`
			rm -rf "$link_name"
			ln -sf "$target_name" "$link_name"
		fi
	)
}

n8l::has_cmd() {
	local command=${1?command is required}
	command -v "$command" > /dev/null 2>&1
}

# check that all required cli programs are present
n8l::require_cmds() {
	local cmds=("${@?at least one command is required}")
	local errors=()

	# accumulate a list of all missing commands before failing to reduce end-user
	# install/retry cycles
	for c in "${cmds[@]}"; do
		if ! n8l::has_cmd "$c"; then
			errors+=("prog: ${c} is required")
		fi
	done

	if [[ ${#errors[@]} -ne 0 ]]; then
		for e in "${errors[@]}"; do
			n8l::print_error "$e"
		done
		n8l::fail
	fi
}

n8l::fmt() {
	fmt -w 78
}

n8l::usage() {
	n8l::fail "$(cat <<-EOF

		usage: newinstall.sh [-b] [-f] [-h] [-n] [-3|-2] [-t|-T] [-s|-S] [-p]
                         [-P <path-to-python>]
		 -b -- Run in batch mode. Do not ask any questions and install all extra
		       packages.
		 -c -- Attempt to continue a previously failed install.
		 -n -- No-op. Go through the motions but echo commands instead of running
		       them.
		 -P [PATH_TO_PYTHON] -- Use a specific python interpreter for EUPS.
		 -2 -- use Python 2 (no longer supported -- fatal error)
		 -3 -- Use Python 3 if the script is installing its own Python. (default)
		 -t -- Use pre-compiled EUPS "tarball" packages, if available.
		 -T -- DO NOT use pre-compiled EUPS "tarball" packages.
		 -s -- Use EUPS source "eupspkg" packages, if available.
		 -S -- DO NOT use EUPS source "eupspkg" packages.
		 -p -- Preserve EUPS_PKGROOT environment variable.
		 -h -- Display this help message.

		EOF
	)"
}

n8l::miniconda_slug() {
	echo "miniconda${LSST_PYTHON_VERSION}-${LSST_MINICONDA_VERSION}"
}

n8l::python_env_slug() {
	echo "$(n8l::miniconda_slug)-${LSST_LSSTSW_REF}"
}

n8l::eups_slug() {
	local eups_slug=$LSST_EUPS_VERSION

	if [[ -n $LSST_EUPS_GITREV ]]; then
		eups_slug=$LSST_EUPS_GITREV
	fi

	echo "$eups_slug"
}

n8l::eups_base_dir() {
	echo "${LSST_HOME}/eups"
}

n8l::eups_dir() {
	echo "$(n8l::eups_base_dir)/$(n8l::eups_slug)"
}

#
# version the eups product installation path using the *complete* python
# environment
#
# XXX this will probably need to be extended to include the compiler used for
# binary tarballs
#
n8l::eups_path() {
	echo "${LSST_HOME}/stack/$(n8l::python_env_slug)"
}

n8l::parse_args() {
	local OPTIND
	local opt

	while getopts cbhnP:32tTsSp opt; do
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
				n8l::fail 'Python 2.x is no longer supported.'
				;;
			3)
				# noop
				;;
			t)
				LSST_EUPS_USE_TARBALLS=true
				;;
			T)
				LSST_EUPS_USE_TARBALLS=false
				;;
			s)
				LSST_EUPS_USE_EUPSPKG=true
				;;
			S)
				LSST_EUPS_USE_EUPSPKG=false
				;;
			p)
				PRESERVE_EUPS_PKGROOT_FLAG=true
				;;
			h|*)
				n8l::usage
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
n8l::sys::osfamily() {
	local __osfamily_result=${1?osfamily result variable is required}
	local __release_result=${2?release result variable is required}
	local __debug=$3

	local __osfamily
	local __release

	case $(uname -s) in
		Linux*)
			local release_file='/etc/redhat-release'
			if [[ ! -e $release_file ]]; then
				[[ $__debug == true ]] && n8l::print_error "unknown osfamily"
			fi
			__osfamily="redhat"

			# capture only major version number because "posix character classes"
			if [[ ! $(<"$release_file") =~ release[[:space:]]*([[:digit:]]+) ]]; then
				[[ $__debug == true ]] && n8l::print_error "unable to find release string"
			fi
			__release="${BASH_REMATCH[1]}"
			;;
		Darwin*)
			__osfamily="osx"

			if ! release=$(sw_vers -productVersion); then
				[[ $__debug == true ]] && n8l::print_error "unable to find release string"
			fi
			__release=$(n8l::trim "$release")
			;;
		*)
			[[ $__debug == true ]] && n8l::print_error "unknown osfamily"
			;;
	esac

	# bash 3.2 does not support `declare -g`
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
n8l::sys::platform() {
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
					__target_cc=devtoolset-6
					;;
				7)
					__platform=el7
					__target_cc=devtoolset-6
					;;
				*)
					[[ $__debug == true ]] && n8l::print_error "unsupported release: $__release"
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
					[[ $__debug == true ]] && n8l::print_error "unsupported release: $__release"
					;;
			esac
			;;
		*)
			[[ $__debug == true ]] && n8l::print_error "unsupported osfamily: $__osfamily"
			;;
	esac

	# bash 3.2 does not support `declare -g`
	eval "$__platform_result=$__platform"
	eval "$__target_cc_result=$__target_cc"
}

# http://stackoverflow.com/questions/1527049/join-elements-of-an-array#17841619
n8l::join() {
	local IFS=${1?separator is required}
	shift

	echo -n "$*"
}

n8l::default_eups_pkgroot() {
	local use_eupspkg=${1:-true}
	local use_tarballs=${2:-false}

	local osfamily
	local release
	local platform
	local target_cc
	declare -a roots
	local base_url=$LSST_EUPS_PKGROOT_BASE_URL

	local pyslug
	pyslug=$(n8l::python_env_slug)

	# only probe system *IF* tarballs are desired
	if [[ $use_tarballs == true ]]; then
		n8l::sys::osfamily osfamily release
	fi

	if [[ -n $osfamily && -n $release ]]; then
		n8l::sys::platform "$osfamily" "$release" platform target_cc
	fi

	if [[ -n $base_url ]]; then
		if [[ -n $platform && -n $target_cc ]]; then
			# binary "tarball" pkgroot
			roots+=( "${base_url}/${osfamily}/${platform}/${target_cc}/${pyslug}" )
		fi

		if [[ $use_eupspkg == true ]]; then
			roots+=( "${base_url}/src" )
		fi
	fi

	echo -n "$(n8l::join '|' "${roots[@]}")"
}

# XXX this sould be split into two functions that echo values.  This would
# allow them to be called directly and remove the usage of the global
# variables.
n8l::config_curl() {
	# Prefer system curl; user-installed ones sometimes behave oddly
	if [[ -x /usr/bin/curl ]]; then
		CURL=${CURL:-/usr/bin/curl}
	else
		CURL=${CURL:-curl}
	fi

	# disable curl progress meter unless running under a tty -- this is intended
	# to reduce the amount of console output when running under CI
	CURL_OPTS='-#'
	if [[ ! -t 1 ]]; then
		CURL_OPTS='-sS'
	fi
}

n8l::miniconda::install() {
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
			n8l::fail "Cannot install miniconda: unsupported platform $(uname -s)"
			;;
	esac

	# the miniconda installer internally uses bzip2
	n8l::require_cmds bzip2

	miniconda_file_name="Miniconda${py_ver}-${mini_ver}-${ana_platform}.sh"
	echo "::: Deploying ${miniconda_file_name}"

	(
		set -Eeo pipefail

		# Create a temporary directory to download the installation script into
		tmpdir=$(mktemp -d -t miniconda-XXXXXXXX)
		tmpfile="$tmpdir/${miniconda_file_name}"

		# attempt to be a good citizen and not leave tmp files laying around
		# after either a normal exit or an error condition
		# shellcheck disable=SC2064
		trap "{ rm -rf $tmpdir; }" EXIT

		$cmd "$CURL" "$CURL_OPTS" -L \
			"${miniconda_base_url}/${miniconda_file_name}" \
			--output "$tmpfile"

		$cmd bash "$tmpfile" -b -p "$prefix"
	)
}

# configure alt conda channel(s)
n8l::miniconda::config_channels() {
	local channels=${1?channels is required}

	n8l::require_cmds conda

	# remove any previously configured non-default channels
	# XXX allowed to fail
	$cmd conda config --remove-key channels || true

	for c in $channels; do
		$cmd conda config --add channels "$c"
	done

	# remove the default channels
	$cmd conda config --remove channels defaults

	$cmd conda config --show
}

# Install packages on which the stack is known to depend
n8l::miniconda::lsst_env() {
	local py_ver=${1?python version is required}
	local ref=${2?lsstsw git ref is required}

	n8l::require_cmds conda activate

	case $(uname -s) in
		Linux*)
			conda_packages="conda${py_ver}_packages-linux-64.txt"
			;;
		Darwin*)
			conda_packages="conda${py_ver}_packages-osx-64.txt"
			;;
		*)
			n8l::fail "Cannot configure miniconda env: unsupported platform $(uname -s)"
			;;
	esac

	local baseurl="https://raw.githubusercontent.com/lsst/lsstsw/${ref}/etc/"
	local tmpfile

	# conda may leave behind lock files from an uncompleted package installation
	# attempt.  These need to be cleaned up before [re]attempting to install
	# packages.
	$cmd conda clean --lock

	(
		set -Eeo pipefail

		tmpfile=$(mktemp -t "${conda_packages//X/_}.XXXXXXXX")
		# attempt to be a good citizen and not leave tmp files laying around
		# after either a normal exit or an error condition
		# shellcheck disable=SC2064
		trap "{ rm -rf $tmpfile; }" EXIT
		$cmd "$CURL" "$CURL_OPTS" \
			-L \
			"${baseurl}/${conda_packages}" \
			--output "$tmpfile"

		args=()
		args+=('env' 'update')
		args+=('--name' "$LSST_CONDA_ENV_NAME")

		# disable the conda install progress bar when not attached to a tty. Eg.,
		# when running under CI
		if [[ ! -t 1 ]]; then
			args+=("--quiet")
		fi

		args+=("--file" "$tmpfile")

		$cmd conda "${args[@]}"
	)

	# shellcheck disable=SC1091
	source activate "$LSST_CONDA_ENV_NAME"

	# report packages in the current conda env
	conda env export
}

#
# Warn if there's a different version on the server
#
# Don't make this fatal, it should still work for developers who are hacking
# their copy.
#
# Don't attempt to run diff when the script has been piped into the shell
#
n8l::up2date_check() {
	local amidiff
	diff \
		--brief "$0" \
		<($CURL "$CURL_OPTS" -L "$NEWINSTALL_URL") > /dev/null \
		&& amidiff=$? || amidiff=$?

	case $amidiff in
		0) ;;
		1)
			n8l::print_error "$({ cat <<-EOF
				!!! This script differs from the official version on the distribution
				server.  If this is not intentional, get the current version from here:
				${NEWINSTALL_URL}
				EOF
			} | n8l::fmt)"
			;;
		2|*)
			n8l::print_error "$({ cat <<-EOF
				!!! There is an error in comparing the official version with the local
				copy of the script.
				EOF
			} | n8l::fmt)"
			;;
	esac
}

# Discuss the state of Git.
# XXX should probably fail if git version is insufficient under batch mode.
n8l::git_check() {
	if n8l::has_cmd git; then
		local gitvernum
		gitvernum=$(git --version | cut -d\  -f 3)

		local gitver
		# shellcheck disable=SC2046 disable=SC2183
		gitver=$(printf "%02d-%02d-%02d\\n" \
			$(echo "$gitvernum" | cut -d. -f1-3 | tr . ' '))
	fi

	if [[ $gitver < 01-08-04 ]]; then
		if [[ $BATCH_FLAG != true ]]; then
			{ cat <<-EOF
				Detected $(git --version).

				The git version control system is frequently used with LSST software.
				While the LSST stack should build and work even in the absence of git, we
				don not regularly run and test it in such environments. We therefore
				recommend you have at least git 1.8.4 installed with your normal
				package manager.

				EOF
			} | n8l::fmt

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
}

n8l::pyverok() {
	local min_major=${1?min_major is required}
	local min_minor=${2?min_minor is required}
	local py_interp=${3:-python}

	$py_interp -c "import sys
rmaj=${min_major}
rmin=${min_minor}
vmaj = sys.version_info[0]
vmin = sys.version_info[1]
if (vmaj >= rmaj) and (vmin >= rmin):
    sys.exit(0)
else:
    sys.exit(1)"
}

#
#	Test/warn about Python versions, offer to get miniconda if not supported.
#	LSST currently mandates specific versions of Python.  We assume that the
#	python in PATH is the python that will be used to build the stack if
#	miniconda is not installed.
#
n8l::python_check() {
	# Check the version by running a small Python program (taken from the Python
	# EUPS package) XXX this will break if python is not in $PATH
	local py_interp=python
	local min_major=3
	local min_minor=6

	local has_python=false
	local pyok=false
	if n8l::has_cmd $py_interp; then
		has_python=true
		if n8l::pyverok $min_major $min_minor $py_interp; then
			pyok=true
		fi
	fi

	if [[ $pyok != true ]]; then
		if [[ $has_python == true ]]; then
			{ cat <<-EOF

				LSST stack requires Python >= ${min_major}.${min_minor}; you seem to
				have $($py_interp -V 2>&1) on your path ($(command -v $py_interp)).
				EOF
			} | n8l::fmt
		else
			{ cat <<-EOF

				Unable to locate python.

				Please set up a compatible python interpreter, prepend it to your PATH,
				and rerun this script.  Alternatively, we can set up the Miniconda Python
				distribution for you.

				EOF
			} | n8l::fmt
		fi
	fi

	{ cat <<-EOF

		In addition to Python >= ${min_major}.${min_minor}, some LSST packages
		depend on recent versions of numpy, matplotlib, and scipy.  If you do not
		have all of these, the installation may fail.  Using the Miniconda Python
		distribution will ensure all these are set up.

		EOF
	} | n8l::fmt

	while true; do
		read -r -p "$({ cat <<-EOF
			Would you like us to install the Miniconda Python distribution (if
			unsure, say yes)?
			EOF
		} | n8l::fmt)" yn

		case $yn in
			[Yy]* )
				WITH_MINICONDA=true
				break
				;;
			[Nn]* )
				if [[ $pyok != true ]]; then
					{ cat <<-EOF

						Thanks. After you install the required version of Python and the
						required modules, rerun this script to continue the installation.

						EOF
					} | n8l::fmt
					n8l::fail
				fi
				break;
				;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

#
# boostrap a complete miniconda based env that includes configuring conda
# channels and installation of the conda packages.
#
# this appears to be a bug in shellcheck
# shellcheck disable=SC2120
n8l::miniconda::bootstrap() {
	local py_ver=${1?python version is required}
	local mini_ver=${2?miniconda version is required}
	local prefix=${3?prefix is required}
	local __miniconda_path_result=${4?__miniconda_path_result is required}
	local miniconda_base_url=${5:-https://repo.continuum.io/miniconda}
	local lsstsw_ref=$6
	local conda_channels=$7

	local miniconda_base_path="${prefix}/python"
	local miniconda_path
	miniconda_path="${miniconda_base_path}/$(n8l::miniconda_slug)"

	local miniconda_path_old
	miniconda_path_old="${prefix}/$(n8l::miniconda_slug)"

	# remove old unnested miniconda -- the install has hard coded shebangs
	if [[ -e $miniconda_path_old ]]; then
		rm -rf "$miniconda_path_old"
	fi

	if [[ ! -e $miniconda_path ]]; then
		n8l::miniconda::install \
			"$py_ver" \
			"$mini_ver" \
			"$miniconda_path" \
			"$miniconda_base_url"
	fi

	# update miniconda current symlink
	n8l::ln_rel "$miniconda_path" current

	export PATH="${miniconda_path}/bin:${PATH}"

	if [[ -n $conda_channels ]]; then
		n8l::miniconda::config_channels "$conda_channels"
	fi

	if [[ -n $lsstsw_ref ]]; then
		n8l::miniconda::lsst_env "$py_ver" "$lsstsw_ref"
	fi

	# bash 3.2 does not support `declare -g`
	eval "$__miniconda_path_result=$miniconda_path"
}

#
# $EUPS_PYTHON is the Python used to install/run EUPS.  It can be any Python >=
# v2.6
#
# XXX this function should be broken up to enable better unit testing.
n8l::install_eups() {
	if [[ ! -x $EUPS_PYTHON ]]; then
		n8l::fail "$({ cat <<-EOF
			Cannot find or execute '${EUPS_PYTHON}'.  Please set the EUPS_PYTHON
			environment variable or use the -P option to point to a functioning
			Python >= 2.6 interpreter and rerun.
			EOF
		} | n8l::fmt)"
	fi

	local min_major=2
	local min_minor=6

	if ! n8l::pyverok "$min_major" "$min_minor" "$EUPS_PYTHON"; then
		n8l::fail "$({ cat <<-EOF
			EUPS requires Python ${min_major}.${min_minor} or newer; we are using
			$("$EUPS_PYTHON" -V 2>&1) from ${EUPS_PYTHON}.  Please set up a
			compatible python interpreter using the EUPS_PYTHON environment variable
			or the -P command line option.
			EOF
		} | n8l::fmt)"
	fi

	if [[ $EUPS_PYTHON != /usr/bin/python ]]; then
		echo "Using python at ${EUPS_PYTHON} to install EUPS"
	fi

	# if there is an existing, unversioned install, renamed it to "legacy"
	if [[ -e "$(n8l::eups_base_dir)/Release_Notes" ]]; then
		local eups_legacy_dir
		eups_legacy_dir="$(n8l::eups_base_dir)/legacy"
		local eups_tmp_dir="${LSST_HOME}/eups-tmp"

		echo "Moving old EUPS to ${eups_legacy_dir}"

		mv "$(n8l::eups_base_dir)" "$eups_tmp_dir"
		mkdir -p "$(n8l::eups_base_dir)"
		mv "$eups_tmp_dir" "$eups_legacy_dir"
	fi

	echo -n "Installing EUPS ($(n8l::eups_slug))... "

	# remove previous install
	if [[ -e $(n8l::eups_dir) ]]; then
		chmod -R +w "$(n8l::eups_dir)"
		rm -rf "$(n8l::eups_dir)"
	fi

	local eups_build_dir="$LSST_HOME/_build"

	# make is absent from many minimal linux images
	n8l::require_cmds make "${CC:-cc}" which perl awk sed

	if ! ( set -Eeo pipefail
		mkdir "$eups_build_dir"
		cd "$eups_build_dir"

		if [[ -z $LSST_EUPS_GITREV ]]; then
			# Download tarball from github
			$cmd "$CURL" "$CURL_OPTS" -L "$LSST_EUPS_TARURL" | tar xzvf -
			$cmd cd "eups-${LSST_EUPS_VERSION}"
		else
			# Clone from git repository
			$cmd git clone "$EUPS_GITREPO" eups
			$cmd cd eups
			$cmd git checkout "$LSST_EUPS_GITREV"
		fi

		$cmd ./configure \
			--prefix="$(n8l::eups_dir)" \
			--with-eups="$(n8l::eups_path)" \
			--with-python="$EUPS_PYTHON"
		$cmd make install
	) > eupsbuild.log 2>&1 ; then
		n8l::fail "$(cat <<-EOF
			FAILED.
			"See log in eupsbuild.log"
			EOF
		)"
	fi

	# symlinks should be relative to support relocation of the newinstall root

	# update $EUPS_DIR current symlink
	n8l::ln_rel "$(n8l::eups_dir)" current

	# update EUPS_PATH current symlink
	n8l::ln_rel "$(n8l::eups_path)" current

	echo " done."
}

n8l::problem_vars() {
	local problems=(
		EUPS_PATH
		EUPS_PKGROOT
		REPOSITORY_PATH
	)
	local found=()

	for v in ${problems[*]}; do
		if [[ -n ${!v+1} ]]; then
			found+=("$v")
		fi
	done

	echo -n "${found[@]}"
}

n8l::problem_vars_check() {
	local problems=()
	IFS=" " read -r -a problems <<< "$(n8l::problem_vars)"

	if [[ ${#problems} -gt 0 ]]; then
		n8l::print_error "$({ cat <<-EOF
			WARNING: the following environment variables are defined that will affect
			the operation of the LSST build tooling.
			EOF
		} | n8l::fmt)"

		for v in ${problems[*]}; do
			n8l::print_error "${v}=\"${!v}\""
		done

		n8l::print_error "$(cat <<-EOF

			It is recommended that they are undefined before running this script.

			unset ${problems[*]}
			EOF
		)"

		return 1
	fi
}

n8l::generate_loader_bash() {
	local file_name=${1?file_name is required}
	local eups_pkgroot=${2?eups_pkgroot is required}
	local miniconda_path=$3

	if [[ -n $miniconda_path ]]; then
		local cmd_setup_miniconda
		cmd_setup_miniconda="$(cat <<-EOF
			export PATH="${miniconda_path}/bin:\${PATH}"
			export LSST_CONDA_ENV_NAME=\${LSST_CONDA_ENV_NAME:-${LSST_CONDA_ENV_NAME}}
			# shellcheck disable=SC1091
			source activate "\$LSST_CONDA_ENV_NAME"
		EOF
		)"
	fi

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with bash to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		${cmd_setup_miniconda}
		LSST_HOME="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups/$(n8l::eups_slug)"
		source "\${EUPS_DIR}/bin/setups.sh"
		export -f setup
		export -f unsetup

		export EUPS_PKGROOT=\${EUPS_PKGROOT:-$eups_pkgroot}
	EOF
}

n8l::generate_loader_csh() {
	local file_name=${1?file_name is required}
	local eups_pkgroot=${2?eups_pkgroot is required}
	local miniconda_path=$3

	if [[ -n $miniconda_path ]]; then
		local cmd_setup_miniconda
		cmd_setup_miniconda="$(cat <<-EOF
				setenv PATH "${miniconda_path}/bin:\$PATH"
				if ( ! \$?LSST_CONDA_ENV_NAME ) then
					set LSST_CONDA_ENV_NAME="${LSST_CONDA_ENV_NAME}"
				endif
				source "${miniconda_path}/etc/profile.d/conda.csh"
				conda activate "\$LSST_CONDA_ENV_NAME"
			EOF
		)"
	fi

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with (t)csh to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		${cmd_setup_miniconda}
		set LSST_HOME = \`dirname \$0\`
		set LSST_HOME = \`cd \${LSST_HOME} && pwd\`

		# Bootstrap EUPS
		set EUPS_DIR = "\${LSST_HOME}/eups/$(n8l::eups_slug)"
		source "\${EUPS_DIR}/bin/setups.csh"

		if ( ! \${?EUPS_PKGROOT} ) then
		  setenv EUPS_PKGROOT "$eups_pkgroot"
		endif
	EOF
}

n8l::generate_loader_ksh() {
	local file_name=${1?file_name is required}
	local eups_pkgroot=${2?eups_pkgroot is required}
	local miniconda_path=$3

	if [[ -n $miniconda_path ]]; then
		# XXX untested
		local cmd_setup_miniconda
		cmd_setup_miniconda="$(cat <<-EOF
			export PATH="${miniconda_path}/bin:\${PATH}"
			export LSST_CONDA_ENV_NAME=\${LSST_CONDA_ENV_NAME:-${LSST_CONDA_ENV_NAME}}
			# shellcheck disable=SC1091
			source activate "\$LSST_CONDA_ENV_NAME"
		EOF
		)"
	fi

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with ksh to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		${cmd_setup_miniconda}
		LSST_HOME="\$( cd "\$( dirname "\${.sh.file}" )" && pwd )"

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups/$(n8l::eups_slug)"
		source "\${EUPS_DIR}/bin/setups.sh"

		export EUPS_PKGROOT=\${EUPS_PKGROOT:-$eups_pkgroot}
	EOF
}

n8l::generate_loader_zsh() {
	local file_name=${1?file_name is required}
	local eups_pkgroot=${2?eups_pkgroot is required}
	local miniconda_path=$3

	if [[ -n $miniconda_path ]]; then
		# XXX untested
		local cmd_setup_miniconda
		cmd_setup_miniconda="$(cat <<-EOF
			export PATH="${miniconda_path}/bin:\${PATH}"
			export LSST_CONDA_ENV_NAME=\${LSST_CONDA_ENV_NAME:-${LSST_CONDA_ENV_NAME}}
			source activate "\$LSST_CONDA_ENV_NAME"
		EOF
		)"
	fi

	# shellcheck disable=SC2094
	cat > "$file_name" <<-EOF
		# This script is intended to be used with zsh to load the minimal LSST
		# environment
		# Usage: source $(basename "$file_name")

		${cmd_setup_miniconda}
		LSST_HOME=\`dirname "\$0:A"\`

		# Bootstrap EUPS
		EUPS_DIR="\${LSST_HOME}/eups/$(n8l::eups_slug)"
		source "\${EUPS_DIR}/bin/setups.zsh"

		export EUPS_PKGROOT=\${EUPS_PKGROOT:-$eups_pkgroot}
	EOF
}

n8l::create_load_scripts() {
	local prefix=${1?prefix is required}
	local eups_pkgroot=${2?eups_pkgroot is required}
	local miniconda_path=$3

	for sfx in bash ksh csh zsh; do
		echo -n "Creating startup scripts (${sfx}) ... "
		# shellcheck disable=SC2086
		n8l::generate_loader_$sfx \
			"${prefix}/loadLSST.${sfx}" \
			"$eups_pkgroot" \
			$miniconda_path
		echo "done."
	done
}

n8l::print_greeting() {
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
n8l::am_i_sourced() {
	if [ "${FUNCNAME[1]}" = source ]; then
		return 0
	else
		return 1
	fi
}


#
# script main
#
n8l::main() {
	n8l::config_curl

	CONT_FLAG=false
	BATCH_FLAG=false
	NOOP_FLAG=false
	PRESERVE_EUPS_PKGROOT_FLAG=false

	n8l::parse_args "$@"

	{ cat <<-EOF

		LSST Software Stack Builder
		=======================================================================

		EOF
	} | n8l::fmt

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
			n8l::fail "$({ cat <<-EOF
				Please run this script from an empty directory. The LSST stack will be
				installed into it.
				EOF
			} | n8l::fmt)"
		fi
	fi

	# Warn if there's a different version on the server
	if [[ -n $0 && $0 != bash ]]; then
		n8l::up2date_check
	fi

	if [[ $BATCH_FLAG != true ]]; then
		n8l::problem_vars_check
	fi

	n8l::git_check

	# always use miniconda when in batch mode
	if [[ $BATCH_FLAG == true ]]; then
		WITH_MINICONDA=true
	else
		n8l::python_check
	fi

	# Bootstrap miniconda (optional)
	# Note that this will add miniconda to the path
	if [[ $WITH_MINICONDA == true ]]; then
		# this appears to be a bug in shellcheck
		# shellcheck disable=SC2119
		n8l::miniconda::bootstrap \
			"$LSST_PYTHON_VERSION" \
			"$LSST_MINICONDA_VERSION" \
			"$LSST_HOME" \
			'MINICONDA_PATH' \
			"$LSST_MINICONDA_BASE_URL" \
			"$LSST_LSSTSW_REF" \
			"$LSST_CONDA_CHANNELS"
	fi

	# By default we use the PATH Python to bootstrap EUPS.  Set $EUPS_PYTHON to
	# override this or use the -P command line option.  $EUPS_PYTHON is used to
	# install and run EUPS and will not necessarily be the python in the path
	# being used to build the stack itself.
	EUPS_PYTHON=${EUPS_PYTHON:-$(command -v python)}

	if [[ $PRESERVE_EUPS_PKGROOT_FLAG == true ]]; then
		EUPS_PKGROOT=${EUPS_PKGROOT:-$(
			n8l::default_eups_pkgroot \
				$LSST_EUPS_USE_EUPSPKG \
				$LSST_EUPS_USE_TARBALLS
		)}
	else
		EUPS_PKGROOT=$(
			n8l::default_eups_pkgroot \
				$LSST_EUPS_USE_EUPSPKG \
				$LSST_EUPS_USE_TARBALLS
		)
	fi
	n8l::print_error "Configured EUPS_PKGROOT: ${LSST_EUPS_PKGROOT}"

	# Install EUPS
	n8l::install_eups

	# Create the environment loader scripts
	# shellcheck disable=SC2153
	# it can not know that MINICONDA_PATH is created by eval
	# shellcheck disable=SC2086
	n8l::create_load_scripts \
		"$LSST_HOME" \
		"$EUPS_PKGROOT" \
		$MINICONDA_PATH

	# Helpful message about what to do next
	n8l::print_greeting
}

#
# support being sourced as a lib or executed
#
if ! n8l::am_i_sourced; then
	n8l::main "$@"
fi

# vim: tabstop=2 shiftwidth=2 noexpandtab
