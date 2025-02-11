#!/usr/bin/env bash

# Install individual repositories in a specific way.

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

_repo_uri="${_args[*]:0:1}"
_repo_commit="${_args[*]:1:1}"
_repo_pip_install_features="${_args[*]:2:1}"
args=( "${_args[@]:3}" )

_next_script="$(get_curr_dir)"/configure_pip_install_variables.sh
source "$_next_script" \
       __inherit__ "$_next_script" \
       "${args[@]}"

# TorchChat does not support our standard installation method, so we
# hardcode this exception.
if [ "$_repo_uri" = 'https://github.com/pytorch/torchchat.git' ]; then
    python -m pip "${_pip_install_args[@]}" -r install/requirements.txt
else
    python -m pip "${_pip_install_editable_args[@]}" ."$_repo_pip_install_features"
fi

pop_curr_file
