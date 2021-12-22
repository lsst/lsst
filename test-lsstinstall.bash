#!/usr/bin/bash

# Look for a string in stdin; fail with an error if missing.
grepf () {
    line=${BASH_LINENO[grepf]}
    if ! grep "$1" > /dev/null; then
        echo "Line $line: Missing '$1'"
        exit 1
    fi
}

# Expect failure; fail with an error if not.
xfail () {
    line=${BASH_LINENO[xfail]}
    "$@" > /dev/null 2>&1 && echo "Line $line: Failed to fail" && exit 1
    return 0
}

# Fail on any error.
set -e

# Test default case.
./scripts/lsstinstall -n \
    | sed -e 's/rubin-env=[0-9.]*/rubin-env=latest/' \
          -e 's/lsst-scipipe-[0-9.]*/lsst-scipipe-latest/' \
          -e 's:stack/redhat/el7:stack/osx/10.9:' \
          -e 's/miniconda3-py38_4\.9\.2-[0-9.]*/miniconda3-py38_4.9.2-latest/' \
          -e 's/\$ mamba/$ conda/g' \
          -e 's/Linux/Darwin/g' \
          -e s:"$PWD":PWD:g \
    | diff - nominal.out

# Ensure backward compatibility options are ignored.
diff <( ./scripts/lsstinstall -n ) <( ./scripts/lsstinstall -nc -b -t )

# Check EUPS_PKGROOT-affecting options.
./scripts/lsstinstall -n -B | grepf "\$ echo https://eups\.lsst\.codes/stack/src > \$EUPS_PATH/pkgroot"
./scripts/lsstinstall -n -S | grepf "\$ echo https://eups\.lsst\.codes/stack/.* > \$EUPS_PATH/pkgroot"

# Check environment version handling.
./scripts/lsstinstall -n -T w_2021_50 | grepf 'Selected rubin-env=0\.7\.0'
./scripts/lsstinstall -n -T w_2021_20 | grepf 'Selected rubin-env=0\.6\.0'
./scripts/lsstinstall -n -T w_2021_16 | grepf 'Selected rubin-env=0\.5\.0'
./scripts/lsstinstall -n -T w_2021_15 | grepf 'Selected rubin-env=0\.4\.3'
./scripts/lsstinstall -n -T w_2021_11 | grepf 'Selected rubin-env=0\.4\.2'
./scripts/lsstinstall -n -T w_2021_10 | grepf 'Selected rubin-env=0\.4\.1'
./scripts/lsstinstall -n -T w_2021_01 | grepf 'Selected rubin-env=cb4e2dc'
./scripts/lsstinstall -n -T w_2020_30 | grepf 'Selected rubin-env=1a1d771'
./scripts/lsstinstall -n -T w_2020_20 | grepf 'Selected rubin-env=46b24e8'
./scripts/lsstinstall -n -X w_2021_50 | grepf '\$ run_curl -o w_2021_50\.env https://eups\.lsst\.codes/stack/.*/conda-system/miniconda3-py38_4\.9\.2-0\.7\.0/env/w_2021_50\.env'
./scripts/lsstinstall -n -X w_2021_50 | grepf '\$ conda activate lsst-scipipe-0\.7\.0-exact'
./scripts/lsstinstall -n -X w_2021_01 | grepf '\$ run_curl -o w_2021_01\.env https://raw\.githubusercontent\.com/lsst/scipipe_conda_env/cb4e2dc/etc/conda-.*\.lock'
# Hash environments are always exact.
./scripts/lsstinstall -n -X w_2021_01 | grepf '\$ conda activate lsst-scipipe-cb4e2dc$'
./scripts/lsstinstall -n -v 0.4.2 | grepf '\$ [cm][oa][nm][db]a create -y -n lsst-scipipe-0\.4\.2 --strict-channel-priority rubin-env=0\.4\.2'
./scripts/lsstinstall -n -v cb4e2dc | grepf '\$ run_curl -o cb4e2dc\.env https://raw\.githubusercontent\.com/lsst/scipipe_conda_env/cb4e2dc/etc/conda-.*\.lock'
./scripts/lsstinstall -n -v cb4e2dc | grepf '\$ [cm][oa][nm][db]a create -y -n lsst-scipipe-cb4e2dc --file cb4e2dc\.env'

# Check environment name handling.
./scripts/lsstinstall -n -e foo-lsst | grepf '\$ conda activate foo-lsst'

# Check explicit EUPS root.
./scripts/lsstinstall -n -E https://foo.lsst.test | grepf "\$ echo https://foo\.lsst\.test/.*/conda-system/miniconda3-py38_4\.9\.2-0\.7\.0|https://foo\.lsst\.test/src > \$EUPS_PATH/pkgroot"

# Check explicit and implicit conda path and environment update handling.
testdir=./testconda$$
./scripts/lsstinstall -n -P "$testdir" | grepf '\$ bash Mambaforge-.*-x86_64\.sh -b -p '"$testdir"
( 
    mkdir -p "$testdir"/bin
    xfail ./scripts/lsstinstall -n -P "$testdir"
    touch "$testdir"/bin/conda "$testdir"/bin/mamba
    chmod 700 "$testdir"/bin/conda "$testdir"/bin/mamba
    ./scripts/lsstinstall -n -P "$testdir" | grepf 'Using existing conda at '"$testdir"
    export PATH=$PATH:"$testdir"/bin
    export CONDA_EXE="$testdir"/bin/conda
    ./scripts/lsstinstall -n | grepf 'Using existing conda at '"$testdir"
    ./scripts/lsstinstall -n | grepf '\$ mamba create '

    mkdir -p "$testdir"/envs/foo-lsst
    ./scripts/lsstinstall -n -u -e foo-lsst | grepf 'Updating rubin-env='

    rm -rf "$testdir"
)

# Test for argument parsing failures
xfail ./scripts/lsstinstall -n -v cb4e2dc -T w_2021_11
xfail ./scripts/lsstinstall -n -v cb4e2dc -X w_2021_11
xfail ./scripts/lsstinstall -n -T w_2021_11 -X w_2021_11
xfail ./scripts/lsstinstall -n -T
xfail ./scripts/lsstinstall -n -X
xfail ./scripts/lsstinstall -n -v
xfail ./scripts/lsstinstall -n -e
xfail ./scripts/lsstinstall -n -P
xfail ./scripts/lsstinstall -n -E
xfail ./scripts/lsstinstall -n -Z
echo "ok"
