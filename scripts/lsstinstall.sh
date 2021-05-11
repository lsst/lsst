#!/bin/sh

# Manage a stack installation or an lsstsw clone
# Installs conda if an existing one is not used
# Creates lsst-scipipe-{version} environment if it doesn't exist
# Creates an eups "stack" directory for the environment if it doesn't exist

# Default values
dryrun=
miniforge_version=latest
rubinenv_version=latest
eups_root=https://eups.lsst.codes/stack
use_tarball=false
use_source=true

print_error () {
    >&2 echo "$@"
}

fail () {
    print_error "$@"
    exit 1
}

# Parse arguments

usage () {
    cat <<EOF
usage: lsstinstall.sh [-n] [-t] [-S]
       [-T EUPS_TAG | -X EUPS_TAG | -v RUBINENV_VERSION]
       [-e ENV_NAME] [-P CONDA_PATH] [-m MINIFORGE_VERSION] [-E EUPS_URL] [-h]
    Installs the Rubin software conda environment.
    Enables the eups distrib install command for Science Pipelines packages.

    -n  -- No-op.  Echo commands instead of running.
    -t  -- Use pre-compiled EUPS "tarball" packages, if available.
    -S  -- DO NOT use EUPS source packages.
    -T EUPS_TAG
        -- Select the rubin-env version used to build the given EUPS_TAG
    -X EUPS_TAG
        -- Select the exact environment used to build the given EUPS_TAG
    -v RUBINENV_VERSION
        -- Select a particular rubin-env version (default=latest).
    -e ENV_NAME
        -- Specify the environment name to use; if it exists, assume that
           it is compatible and should be used.
    -P CONDA_PATH
        -- Use an existing conda installation (default=create a new one)..
    -m MINIFORGE_VERSION
        -- Select a particular miniforge/mambaforge version (default=latest).
    -E EUPS_URL
        -- Select a different EUPS root URL
           (default=https://eups.lsst.codes/stack).
    -b  -- ignored for backward compatibility.
    -c  -- ignored for backward compatibility.
    -h  -- Display this help message.
EOF
    exit 1
}

while getopts ntST:X:v:e:P:m:E:bch opt; do
    case "$opt" in
        n)
            dryrun="echo"
            ;;
        t)
            use_tarball=true
            ;;
        S)
            use_source=false
            ;;
        T)
            eups_tag="$OPTARG"
            ;;
        X)
            eups_tag="$OPTARG"; exact=true
            ;;
        v)
            rubinenv_version="$OPTARG"
            ;;
        e)
            rubinenv_name="$OPTARG"
            ;;
        P)
            conda_path="$OPTARG"
            ;;
        m)
            miniforge_version="$OPTARG"
            ;;
        E)
            eups_root="$OPTARG"
            ;;
        b | c)
            ;;
        h)
            usage
            ;;
        *)
            print_error "Unknown option: $opt"
            usage
            ;;
    esac
done

# Configure

cwd=$(pwd)

platform="$(uname -s)"
case "$platform" in
    Linux | Darwin)
        ;;
    *)
        fail "Unknown platform: $platform"
        ;;
esac

arch="$(uname -m)"
case "$arch" in
    x86_64 | aarch64 | arm64)
        ;;
    *)
        fail "Unknown architecture: $arch"
        exit 1
        ;;
esac

run_curl () {
    _c=curl
    _opt="-sS"
    [ -x /usr/bin/curl ] && _c=/usr/bin/curl
    [ -t 1 ] && _opt="-#"
    $_c -fL --retry 3 $_opt "$@"
}

# Activate conda, installing if necessary

if [ -z "$(command -v conda)" ]; then
    conda_path=$CONDA_PREFIX
fi
conda_path="${conda_path:-$cwd/conda}"
if [ -x "$conda_path/bin/conda" ]; then
    echo "Using existing conda at $conda_path"
else
    [ -e "$conda_path" ] && \
        fail "$conda_path exists but does not appear to contain conda"
    echo "Installing Mambaforge conda at $conda_path"
    url="https://github.com/conda-forge/miniforge/releases"
    if [ "$miniforge_version" = latest ]; then
        url="$url/latest/download"
    else
        url="$url/download/$miniforge_version"
    fi
    url="$url/Mambaforge-$platform-${arch}.sh"
    $dryrun run_curl -O "$url" \
        || fail "Unable to get Mambaforge script for $platform $arch from $url"
    $dryrun bash "Mambaforge-$platform-${arch}.sh" -b -p "$conda_path" \
        || fail "Unable to install Mambaforge"
    $dryrun rm "Mambaforge-$platform-${arch}.sh"
fi
if [ -z "$dryrun" ]; then
    __conda_setup=$("$conda_path/bin/conda" "shell.$(basename "$SHELL")" \
        hook 2>/dev/null) || fail "Unknown shell"
    eval "$__conda_setup" || fail "Unable to start conda"
fi
mamba=conda
command -v mamba >/dev/null && mamba=mamba && export MAMBA_NO_BANNER=1

# Determine rubin-env version

src_root="$eups_root/src"
if [ -n "$eups_tag" ]; then
    rubinenv_version=$(run_curl "$src_root/tags/${eups_tag}.list" \
        | grep '^#CONDA_ENV=' | cut -d= -f2 || echo "latest")
    # if https://github.com/lsst/scipipe_conda_env.git@hash
    # separate into URL and hash
    # platform = linux-64 or osx-64
    # https://raw.githubusercontent.com/lsst/scipipe_conda_env/$hash/etc/conda-${platform}.lock
fi
if [ -z "$dryrun" ] && [ "$rubinenv_version" = latest ]; then
    rubinenv_version=$(conda search --json rubin-env \
        | grep '"version":' | tail -1 | cut -d\" -f4)
fi

# Determine EUPS binary root

if [ "$platform" = Linux ]; then
    eups_platform="redhat/el7/conda-system/miniconda3-py38_4.9.2-$rubinenv_version"
else
    eups_platform="osx/10.9/conda-system/miniconda3-py38_4.9.2-$rubinenv_version"
fi
binary_root="$eups_root/${eups_platform}"

# Install rubin-env environment if necessary

rubinenv_name=${rubinenv_name:-lsst-scipipe-$rubinenv_version}
if conda info --envs --json | grep "\"$rubinenv_name\"" > /dev/null 2>&1; then
    echo "Using existing environment $rubinenv_name"
# elif rubinenv_version is a hash, load that
elif [ "$exact" = true ]; then
    rubinenv_name="${rubinenv_name}-exact"
    url="$binary_root/env/${eups_tag}.env"
    $dryrun run_curl -O "$url" \
        || fail "Unable to download environment spec for tag $eups_tag"
    $dryrun $mamba create -y -n "$rubinenv_name" --file "${eups_tag}.env"
    $dryrun rm "${eups_tag}.env"
else
    $dryrun $mamba create -y -n "$rubinenv_name" "rubin-env=$rubinenv_version"
fi

# Create eups stack and set EUPS_PKGROOT

EUPS_PATH="$cwd/stack/$rubinenv_name"
$dryrun mkdir -p "$EUPS_PATH/site" "$EUPS_PATH/ups_db"

if [ "$use_source" = true ]; then
    if [ "$use_tarball" = true ]; then
        EUPS_PKGROOT="$binary_root|$src_root"
    else
        EUPS_PKGROOT="$src_root"
    fi
else
    if [ "$use_tarball" = true ]; then
        EUPS_PKGROOT="$binary_root"
    else
        EUPS_PKGROOT=""
    fi
fi

# Create load scripts

if [ -z "$dryrun" ]; then
    cat > loadLSST.bash <<EOF
__conda_setup="\$($conda_path/bin/conda shell.\$(basename "\$SHELL") hook 2>/dev/null)" \\
    || { echo "Unknown shell"; exit 1; }
eval "\$__conda_setup" || { echo "Unable to start conda"; exit 1; }
export LSST_CONDA_ENV_NAME=\${1:-\${LSST_CONDA_ENV_NAME:-$rubinenv_name}}
conda activate "\$LSST_CONDA_ENV_NAME"
export EUPS_PATH="$EUPS_PATH"
export RUBIN_EUPS_PATH="\$EUPS_PATH"
export EUPS_PKGROOT="$EUPS_PKGROOT"
EOF
    cat > envconfig <<EOF
source loadLSST.\$(basename "\$SHELL") # passes arguments
[ -e "$EUPS_PATH/site/manifest.remap" ] \
    || ln -s etc/manifest.remap "$EUPS_PATH/site/manifest.remap"
setup -r "${cwd}/lsst_build"
EOF
else
    echo "EUPS_PKGROOT=$EUPS_PKGROOT"
    echo "cat > loadLSST.bash"
    echo "cat > envconfig"
fi
for ext in ash zsh; do
    $dryrun ln loadLSST.bash "loadLSST.$ext"
done

cat <<EOF

Bootstrap complete. To continue installing (and to use) the LSST stack type
one of:
    source "${cwd}/loadLSST.bash"  # for bash
    source "${cwd}/loadLSST.ksh"   # for ksh
    source "${cwd}/loadLSST.zsh"   # for zsh
or
    source "${cwd}/envconfig"      # for lsstsw clones

Individual LSST packages may now be installed with the usual \`eups distrib
install\` command.  For example, to install the latest weekly release of the
LSST Science Pipelines full distribution, use:

    eups distrib install -t w_latest lsst_distrib

An official release tag such as "v21_0_0" can also be used.

Next, read the documentation at
    https://pipelines.lsst.io
and feel free to ask any questions via the LSST Community forum:
    https://community.lsst.org/c/support
EOF
# vim: tabstop=4 shiftwidth=4 expandtab
