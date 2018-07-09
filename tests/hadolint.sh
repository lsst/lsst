#!/bin/bash

set -e
shopt -s globstar nullglob

CHECK=( **/Dockerfile )
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
  docker run -ti -v "$(pwd):$(pwd)" -w "$(pwd)" \
    hadolint/hadolint hadolint "$f"
done

# vim: tabstop=2 shiftwidth=2 expandtab
