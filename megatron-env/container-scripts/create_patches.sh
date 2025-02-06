#!/usr/bin/env bash

# Create patched files to put into the container later.

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

source "$(get_curr_dir)"/../configuration.sh

# Create the patched TransformerEngine file.
sed '/^    props = torch.cuda.get_device_properties(torch.cuda.current_device())$/i \    if not torch.cuda.is_available():\
        import warnings\
        warnings.warn("No GPU found; TransformerEngine may not work correctly without one.")\
        return (0, 0)' \
    "$(echo "${patched_files[*]:0:1}" | tr -s ':' | cut -d ':' -f 1)" \
    > "$(echo "${patched_files[*]:0:1}" | tr -s ':' | cut -d ':' -f 2)"

pop_curr_file
