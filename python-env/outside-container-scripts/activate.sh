#!/usr/bin/env bash

# Configure the software environment used outside the container.

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

source "$(get_curr_dir)"/../../global_configuration.sh

# JSC machine activation steps
if [ "$machine_name" = jsc ] \
       || [ "$machine_name" = jwb ] \
       || [ "$machine_name" = jwc ] \
       || [ "$machine_name" = jrc ]; then
    _next_script="$(get_curr_dir)"/../jsc/_activate.sh
    source "$_next_script" \
           __inherit__ "$_next_script" \
           "${_args[@]}"
elif [ "$machine_name" = bsc ] \
       || [ "$machine_name" = mn5a ]; then
    _next_script="$(get_curr_dir)"/../bsc/_activate.sh
    source "$_next_script" \
           __inherit__ "$_next_script" \
           "${_args[@]}"
fi

source "$(get_curr_dir)"/../configuration.sh

# Cache configuration
source "$(get_curr_dir)"/../../global-scripts/configure_caches.sh

pop_curr_file
