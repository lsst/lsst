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

LSST_EUPS_VERSION=${LSST_EUPS_VERSION:-2.1.5}

LSST_EUPS_GITREV=${LSST_EUPS_GITREV:-}
LSST_EUPS_GITREPO=${LSST_EUPS_GITREPO:-https://github.com/RobertLuptonTheGood/eups.git}
LSST_EUPS_TARURL=${LSST_EUPS_TARURL:-https://github.com/RobertLuptonTheGood/eups/archive/${LSST_EUPS_VERSION}.tar.gz}

LSST_EUPS_PKGROOT_BASE_URL=${LSST_EUPS_PKGROOT_BASE_URL:-https://eups.lsst.codes/stack}
LSST_EUPS_USE_TARBALLS=${LSST_EUPS_USE_TARBALLS:-false}
LSST_EUPS_USE_EUPSPKG=${LSST_EUPS_USE_EUPSPKG:-true}

LSST_MINICONDA_VERSION=${LSST_MINICONDA_VERSION:-4.7.12}
# this git ref controls which set of conda packages are used to initialize the
# the default conda env defined in scipipe_conda_env git package (RFC-553).
LSST_SPLENV_REF=${LSST_SPLENV_REF:-${LSST_LSSTSW_REF:-1a1d771}}
LSST_MINICONDA_BASE_URL=${LSST_MINICONDA_BASE_URL:-https://repo.continuum.io/miniconda}
LSST_CONDA_CHANNELS=${LSST_CONDA_CHANNELS:-"conda-forge"}
LSST_CONDA_ENV_NAME=${LSST_CONDA_ENV_NAME:-lsst-scipipe-${LSST_SPLENV_REF}}
LSST_USE_CONDA_SYSTEM=${LSST_USE_CONDA_SYSTEM:-true}

# these optional env vars may be used by functions but should be considered
# unstable and for internal testing only.
#
# LSST_OS_FAMILY
# LSST_OS_RELEASE
# LSST_PLATFORM
# LSST_COMPILER

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

		usage: newinstall.sh [-b] [-c] [-f] [-h] [-n] [-g|-G] [-t|-T] [-s|-S] [-p]
                         [-P <path-to-conda>]
		 -b -- Run in batch mode. Do not ask any questions and install all extra
		       packages.
		 -c -- Attempt to continue a previously failed install.
		 -n -- No-op. Go through the motions but echo commands instead of running
		       them.
		 -P [PATH_TO_CONDA] -- Use a specific miniconda installation at path.
		 -g -- Preserve LSST_COMPILER or use platform compilers for tarballs (deprecated)
		 -G -- Target conda compilers for tarballs (default)
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
	echo "miniconda3-${LSST_MINICONDA_VERSION}"
}

n8l::python_env_slug() {
	echo "$(n8l::miniconda_slug)-${LSST_SPLENV_REF}"
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

	while getopts cbhnP:gGtTsSp opt; do
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
				LSST_CONDA_BASE=$OPTARG
				;;
			g)
				LSST_USE_CONDA_SYSTEM=false
				;;
			G)
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
				7)
					__platform=el7
					__target_cc=devtoolset-8
					;;
				8)
					__platform=el8
					__target_cc=devtoolset-8
					;;
				*)
					[[ $__debug == true ]] && n8l::print_error "unsupported release: $__release"
					;;
			esac
			;;
		osx)
			case $__release in
				# XXX bash 3.2 on osx does not support case fall-through
				10.9.* | 10.1?.* | 10.1?)
					__platform=10.9
					__target_cc=clang-1000.10.44.4
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
	local use_conda_system=${3:-true}

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

	osfamily=${LSST_OS_FAMILY:-$osfamily}
	release=${LSST_OS_RELEASE:-$release}

	if [[ -n $osfamily && -n $release ]]; then
		n8l::sys::platform "$osfamily" "$release" platform target_cc
	fi

	platform=${LSST_PLATFORM:-$platform}
	if [[ $use_conda_system == true ]]; then
		LSST_COMPILER=conda-system
	fi
	target_cc=${LSST_COMPILER:-$target_cc}

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
	local mini_ver=${1?miniconda version is required}
	local prefix=${2?prefix is required}
	local miniconda_base_url=${3:-https://repo.continuum.io/miniconda}

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

	miniconda_file_name="Miniconda3-${mini_ver}-${ana_platform}.sh"
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
	$cmd conda config --env --remove-key channels 2>/dev/null || true

	for c in $channels; do
		$cmd conda config --env --add channels "$c"
	done

	$cmd conda config --env --set channel_priority strict
	$cmd conda config --env --show
}

# Install packages on which the stack is known to depend
n8l::miniconda::lsst_env() {
	local ref=${1?lsstsw git ref is required}
	local miniconda_path=${2?miniconda path is required}
	local conda_channels=${3}

	case $(uname -s) in
		Linux*)
			conda_packages="conda-linux-64.lock"
			;;
		Darwin*)
			conda_packages="conda-osx-64.lock"
			;;
		*)
			n8l::fail "Cannot configure miniconda env: unsupported platform $(uname -s)"
			;;
	esac

	local baseurl="https://raw.githubusercontent.com/lsst/scipipe_conda_env/${ref}/etc/"
	local tmpfile

	(
		set -Eeo pipefail

		tmpfile=$(mktemp -t "${conda_packages//X/_}.XXXXXXXX")
		# remove unneccesary tmpfile created by mktemp, the (unique) tmpfile name provided by mktemp 
		# is used to create a different tmpfile with extension .yml
		rm -rf "${tmpfile}"
		tmpfile="${tmpfile}.yml"
		# attempt to be a good citizen and not leave tmp files laying around
		# after either a normal exit or an error condition
		# shellcheck disable=SC2064
		trap "{ rm -rf $tmpfile; }" EXIT
		$cmd "$CURL" "$CURL_OPTS" \
			-L \
			"${baseurl}/${conda_packages}" \
			--output "$tmpfile"

		args=()
		args+=('create')
		args+=('--name' "$LSST_CONDA_ENV_NAME")

		# disable the conda install progress bar when not attached to a tty. Eg.,
		# when running under CI
		if [[ ! -t 1 ]]; then
			args+=("--quiet")
		fi

		args+=("--file" "$tmpfile")

		$cmd conda "${args[@]}"
		echo "Cleaning conda environment..."
		conda clean -y -a > /dev/null
		echo "done"
	)

	# Switch to installed conda environment
	conda activate "$LSST_CONDA_ENV_NAME"

	if [[ -n $conda_channels ]]; then
		n8l::miniconda::config_channels "$conda_channels"
	fi

	# report packages in the current conda env
	conda env export
	conda deactivate
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

#
#	Test/warn about Python versions, offer to get miniconda if not supported.
#	LSST currently mandates specific versions of Python.  We assume that the
#	python in PATH is the python that will be used to build the stack if
#	miniconda is not installed.
#
n8l::conda_check() {
	while true; do
		read -r -p "$({ cat <<-EOF
			Would you like us to install Miniconda distribution (if
			unsure, say yes)?
			EOF
		} | n8l::fmt)" yn

		case $yn in
			[Yy]* )
				break
				;;
			[Nn]* )
				{ cat <<-EOF
					Thanks. After you install the required version of conda,
					rerun this script with the -P [PATH_TO_CONDA] to continue
					the installation.
					EOF
				} | n8l::fmt
				n8l::fail
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
	local miniconda_path=${1?miniconda path is required}
	local mini_ver=${2?miniconda version is required}
	local prefix=${3?prefix is required}
	local __miniconda_path_result=${4?__miniconda_path_result is required}
	local miniconda_base_url=${5:-https://repo.continuum.io/miniconda}
	local splenv_ref=$6
	local conda_channels=$7

	local performed_install=false

	# Clear arguments for source
	while (( "$#" )); do
		shift
	done

	if [[ -z $miniconda_path ]]; then
		local miniconda_base_path="${prefix}/conda"
		miniconda_path="${miniconda_base_path}/$(n8l::miniconda_slug)"
		if [[ ! -e $miniconda_path ]]; then
			echo "Installing conda at ${miniconda_path}"
			n8l::miniconda::install \
				"$mini_ver" \
				"$miniconda_path" \
				"$miniconda_base_url"
			# only miniconda current symlink if we installed miniconda
			n8l::ln_rel "$miniconda_path" current
			performed_install=true
		fi
	fi

	if [[ $performed_install == false ]]; then
		(
			export PATH="${miniconda_path}/bin:${PATH}"
			n8l::require_cmds conda
		)
		echo "Using conda at ${miniconda_path}"
	fi

	# Activate the base conda environment before continuing
	# shellcheck disable=SC1090
	source "$miniconda_path/bin/activate"

	if [[ -e ${miniconda_path}/envs/${LSST_CONDA_ENV_NAME} ]]; then
		echo "An environment named ${LSST_CONDA_ENV_NAME} already exists"
	fi

	if [[ -n $splenv_ref ]]; then
		n8l::miniconda::lsst_env "$splenv_ref" "$miniconda_path" "$conda_channels"
	fi

	# Deactivate conda
	conda deactivate

	# bash 3.2 does not support `declare -g`
	eval "$__miniconda_path_result=$miniconda_path"
}

#
# $EUPS_PYTHON is the Python used to install/run EUPS.  It can be any Python >=
# v2.6
#
# XXX this function should be broken up to enable better unit testing.
n8l::install_eups() {
	# We have already verified conda is installed - no need to check
	echo "Using python at ${EUPS_PYTHON} to install EUPS"
	conda activate "$LSST_CONDA_ENV_NAME"

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
	n8l::require_cmds make awk sed

	if [[ $LSST_USE_CONDA_SYSTEM != true ]]; then
		n8l::require_cmds "${CC:-cc}"
	fi

	if ! ( set -Eeo pipefail
		mkdir "$eups_build_dir"
		cd "$eups_build_dir"

		if [[ -z $LSST_EUPS_GITREV ]]; then
			# Download tarball from github
			$cmd "$CURL" "$CURL_OPTS" -L "$LSST_EUPS_TARURL" | tar xzvf -
			$cmd cd "eups-${LSST_EUPS_VERSION}"
		else
		  n8l::require_cmds git
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

	conda deactivate

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
			export LSST_CONDA_ENV_NAME=\${LSST_CONDA_ENV_NAME:-${LSST_CONDA_ENV_NAME}}
			# shellcheck disable=SC1091
			source "${miniconda_path}/bin/activate" "\$LSST_CONDA_ENV_NAME"
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
			export LSST_CONDA_ENV_NAME=\${LSST_CONDA_ENV_NAME:-${LSST_CONDA_ENV_NAME}}
			# shellcheck disable=SC1091
			source "${miniconda_path}/bin/activate" "\$LSST_CONDA_ENV_NAME"
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
			export LSST_CONDA_ENV_NAME=\${LSST_CONDA_ENV_NAME:-${LSST_CONDA_ENV_NAME}}
			source "${miniconda_path}/bin/activate" "\$LSST_CONDA_ENV_NAME"
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
		if [[ -z $LSST_CONDA_BASE ]]; then
			n8l::conda_check
		fi
	fi

	# Bootstrap miniconda (optional)
	# Note that this will add miniconda to the path
	# this appears to be a bug in shellcheck
	# shellcheck disable=SC2119
	n8l::miniconda::bootstrap \
		"$LSST_CONDA_BASE" \
		"$LSST_MINICONDA_VERSION" \
		"$LSST_HOME" \
		'MINICONDA_PATH' \
		"$LSST_MINICONDA_BASE_URL" \
		"$LSST_SPLENV_REF" \
		"$LSST_CONDA_CHANNELS"

	# Use conda base environment's python
	# shellcheck disable=SC2153
	EUPS_PYTHON=${MINICONDA_PATH}/bin/python

	if [[ $PRESERVE_EUPS_PKGROOT_FLAG == true ]]; then
		EUPS_PKGROOT=${EUPS_PKGROOT:-$(
			n8l::default_eups_pkgroot \
				$LSST_EUPS_USE_EUPSPKG \
				$LSST_EUPS_USE_TARBALLS \
				$LSST_USE_CONDA_SYSTEM
		)}
	else
		EUPS_PKGROOT=$(
			n8l::default_eups_pkgroot \
				$LSST_EUPS_USE_EUPSPKG \
				$LSST_EUPS_USE_TARBALLS \
				$LSST_USE_CONDA_SYSTEM
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
