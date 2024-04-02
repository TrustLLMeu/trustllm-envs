#!/usr/bin/env bash

# Configure the software environment used inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

# HuggingFace libraries cache configuration
source "$(get_curr_dir)"/../../global-scripts/configure_hf_caches.sh

# If we are _not_ doing the setup, we want some extra behavior:
# 1. Put HuggingFace libraries into offline mode because of JSC system
#    compute nodes not having internet access.
# 2. Quit and warn the user that the `venv` does not exist.
if [ "$#" -eq 0 ] || ! [ "$1" = setup ]; then
    # Put HuggingFace libraries into offline mode.
    source "$(get_curr_dir)"/../../global-scripts/configure_hf_offline.sh

    # If the `venv` directory exists, source from it, otherwise
    # complain.
    if ! [ -d "$venv_dir" ]; then
        echo 'Cannot find Python virtual environment. Please execute' \
             "\`bash outside-container-scripts/set_up_apptainer.sh\` or" \
             'similar.'
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
