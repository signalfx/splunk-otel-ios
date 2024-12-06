#!/bin/sh

# Root path to the project. Assuming the main script,
# which path is in $SCRIPT_DIR read in the main script itself,
# is in Tools subdir of the project folder.
pushd "${SCRIPT_DIR}/.."  > /dev/null
PROJECT_DIR="$(pwd)"
popd > /dev/null
