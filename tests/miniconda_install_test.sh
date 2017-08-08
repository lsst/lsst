#!/bin/bash

set -e

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../scripts/newinstall.sh
. "${DIR}/../scripts/newinstall.sh"

# "stub" out cmd to prevent curl from being run
# shellcheck disable=SC2034
cmd="echo"

# test expected usage
miniconda::install 3 4.2.12 /dne

# abuse the miniconda version param to inject X's into the constructed
# miniconda installer filename to trigger GNU mktemp's tantrum about the
# template being too small
#
# see: DM-11444
miniconda::install 3 X /dne
miniconda::install 3 XX /dne
miniconda::install 3 XXX /dne
