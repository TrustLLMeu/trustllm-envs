#!/usr/bin/env bash

# Start the software setup done inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
if [ "$#" -gt 1 ] && [ "$1" = __inherit__ ]; then
    _curr_file="$2"
    _args=( "${@:3}" )
else
    _curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
    _args=( "$@" )
fi
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

if (("${DEBUG_TRUSTLLM_ENVS:-0}")); then
    printf '  in: %s\n    curr_file = %s\n' \
           "${BASH_SOURCE[0]:-${(%):-%x}}" \
           "$(get_curr_file)"
fi

# -----

_prev_args=( "${_args[@]}" )
_next_script="$(get_curr_dir)"/activate.sh
source "$_next_script" \
       __inherit__ "$_next_script"
_args=( "${_prev_args[@]}" )

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
    "$apptainer_bin" exec --nv "$apptainer_file" \
    bash "$(get_curr_dir)"/../container-scripts/set_up_container.sh \
    "${_args[@]}"

pop_curr_file
