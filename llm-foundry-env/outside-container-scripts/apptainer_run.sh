#!/usr/bin/env bash

# Start arbitrary commands from inside the container.

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

# If the user does not supply an argument, drop them into an
# interactive shell. Similarly, if they try to execute `bash`, handle
# this specifically so we're still in the `venv`.
if [ "$#" -eq 0 ]; then
    args=(
        env
        BASH_ENV'='"$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        bash
        --init-file
        "$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        -i
    )
elif [ "$#" -gt 0 ] && [ "$(basename "$1")" = bash ]; then
    args=(
        env
        BASH_ENV'='"$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        bash
        --init-file
        "$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        "${@:2}"
    )
else
    args=(
        env
        BASH_ENV'='"$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        bash
        --init-file
        "$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        -c
        "${*@Q}"
    )
fi

_patch_file_args=()
for _patch_file_tuple in "${patched_files[@]}"; do
    _file_to_patch="$(echo "$_patch_file_tuple" | tr -s ':' | cut -d ':' -f 1)"
    _patched_file="$(echo "$_patch_file_tuple" | tr -s ':' | cut -d ':' -f 2)"

    _patch_file_args+=( --bind "$_patched_file"':'"$_file_to_patch" )
done

# We unset a bunch of environment variables so they don't disturb our Apptainer.
env -u BASH_ENV -u CC -u CFLAGS -u CMAKE_LIBRARY_PATH -u CMAKE_PREFIX_PATH \
    -u CPATH -u CXX -u CXXFLAGS -u LESSOPEN -u PYTHONPATH \
    "$apptainer_bin" run --nv \
    "${_patch_file_args[@]}" \
    "$apptainer_file" "${args[@]}"

pop_curr_file
