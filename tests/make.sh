#!/bin/bash

set -e
shopt -s globstar nullglob

CHECK=( tests/**/Makefile )
IGNORE=()

for c in "${!CHECK[@]}"; do
  for i in "${IGNORE[@]}"; do
    [[ ${CHECK[c]} == "$i" ]] && unset -v 'CHECK[c]'
  done
done
[[ ${#CHECK[@]} -eq 0 ]] && { echo 'no files to check'; exit 0; }

echo '---'
echo 'check:'
for c in "${CHECK[@]}"; do
  echo "  - ${c}"
done
echo

for f in "${CHECK[@]}"; do
  ( set -e
    cd "$(dirname "$f")"
    echo "checking $f"
    make --dry-run --warn-undefined-variables
  )
done

# vim: tabstop=2 shiftwidth=2 expandtab
