#!/usr/bin/env bash

# Partially configure the software environment used outside the
# container for JSC machines.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../parent_env.sh
if [ "$#" -gt 1 ] && [ "$1" = __inherit__ ]; then
    # If we are inheriting from this environment, we use the parent of
    # this environment for further propagation, but all other
    # locations use the child environment.
    pop_curr_file

    _curr_file="$2"
    _curr_dir="$(dirname "$_curr_file")"
    source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"
    _args=( "${@:3}" )
else
    _args=( "$@" )
fi

if (("${DEBUG_TRUSTLLM_ENVS:-0}")); then
    printf '  in: %s\n    curr_file = %s\n' \
           "${BASH_SOURCE[0]:-${(%):-%x}}" \
           "$(get_curr_file)"
fi

# -----

# Re-use parent environment's script.
source "$parent_env_dir"/jsc/_activate.sh \
       __inherit__ "$(get_curr_file)" \
       "${_args[@]}"

pop_curr_file
