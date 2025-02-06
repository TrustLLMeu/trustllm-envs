#!/usr/bin/env bash

# Dispatch starting arbitrary commands using the selected container
# library.

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
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

if (("${DEBUG_TRUSTLLM_ENVS:-0}")); then
    printf '  in: %s\n    curr_file = %s\n' \
           "${BASH_SOURCE[0]:-${(%):-%x}}" \
           "$(get_curr_file)"
fi

# -----

source "$(get_curr_dir)"/../global_configuration.sh

if [ "$container_library" = apptainer ]; then
    _next_script="$(get_curr_dir)"/outside-container-scripts/apptainer_exec.sh
    source "$_next_script" \
           __inherit__ "$_next_script" \
           "${_args[@]}"
elif [ "$container_library" = docker ]; then
    _next_script="$(get_curr_dir)"/outside-container-scripts/docker_exec.sh
    source "$_next_script" \
           __inherit__ "$_next_script" \
           "${_args[@]}"
else
    echo "Unknown container library \"$container_library\"."
    pop_curr_file
    exit 1
fi

pop_curr_file
