#!/bin/bash

set -eo pipefail

( set -eo pipefail
  cd tests
  make
)

docker run -ti \
  -v"$(pwd):$(pwd)" -w "$(pwd)" \
  -e MODE="$MODE" \
  -e TEST="$TEST" \
  -e BATCH="$BATCH" \
  -e PYVER="$PYVER" \
  -e ANCIENT_BASH="$ANCIENT_BASH" \
  -e MANGLER="$MANGLER" \
  newinstall-testenv:latest bash -lc ./tests/acceptance.sh

# vim: tabstop=2 shiftwidth=2 expandtab
