#!/usr/bin/env bash

# Start the software setup done inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate.sh

if ! [ -f "$apptainer_file" ]; then
    echo 'Cannot find Apptainer container file; please run' \
         "\`nice bash build_container.sh" \
         "&& bash move_built_container_to_active.sh\`."
    pop_curr_file
    exit 1
fi

# We unset a bunch of environment variables so they don't disturb our Apptainer.
env -u BASH_ENV -u CC -u CFLAGS -u CMAKE_LIBRARY_PATH -u CMAKE_PREFIX_PATH \
    -u CPATH -u CXX -u CXXFLAGS -u LESSOPEN -u PYTHONPATH \
    apptainer run --nv "$apptainer_file" \
    bash "$(get_curr_dir)"/../container-scripts/set_up_container.sh "$@"

pop_curr_file
