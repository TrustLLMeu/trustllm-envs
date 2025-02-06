#!/usr/bin/env bash

# Configure the software environment used inside the container.

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

source "$(get_curr_dir)"/../configuration.sh

# HuggingFace libraries cache configuration
source "$(get_curr_dir)"/../../global-scripts/configure_caches.sh

# Build GPU kernels for a certain set of relevant architectures.
source "$(get_curr_dir)"/../../global-scripts/configure_gpu_arch.sh

# Have to explicitly give Triton the directory containing
# `libcuda.so`.
export TRITON_LIBCUDA_PATH=/usr/local/cuda/lib64/stubs

# If we are _not_ doing the setup, we want some extra behavior:
# 1. Put HuggingFace libraries into offline mode because of JSC system
#    compute nodes not having internet access.
# 2. Quit and warn the user that the `venv` does not exist.
if [ "${#_args[@]}" -eq 0 ] || ! [ "${_args[*]:0:1}" = setup ]; then
    # Put HuggingFace libraries into offline mode.
    source "$(get_curr_dir)"/../../global-scripts/configure_hf_offline.sh

    # If the `venv` directory exists, source from it, otherwise
    # complain.
    if ! [ -d "$venv_dir" ]; then
        echo 'Cannot find Python virtual environment. Please execute' \
             "\`nice bash set_up.sh\`."
        pop_curr_file
        exit 1
    else
        # Deactivate any existing `venv` activation.
        [ "$(command -v deactivate)" ] && deactivate

        source "$venv_dir"/bin/activate
    fi
fi

export _ACTIVATED_CONTAINER=1

pop_curr_file
