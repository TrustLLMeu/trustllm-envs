#!/usr/bin/env bash

# Configure the software environment used inside the container.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$curr_file")"
source "$_curr_dir"/../configuration.sh

# HuggingFace libraries cache configuration
source "$_curr_dir"/../../configure_hf_caches.sh

# If we are _not_ doing the setup, we want some extra behavior:
# 1. Put HuggingFace libraries into offline mode because of JSC system
#    compute nodes not having internet access.
# 2. Quit and warn the user that the `venv` does not exist.
if [ "$#" -eq 0 ] || ! [ "$1" = setup ]; then
    # Put HuggingFace libraries into offline mode.
    source "$_curr_dir"/../../configure_hf_offline.sh

    # If the `venv` directory exists, source from it, otherwise
    # complain.
    if ! [ -d "$venv_dir" ]; then
        echo "Please execute \`bash set_up.sh\`."
        exit 1
    else
        # Deactivate any existing `venv` activation.
        [ "$(command -v deactivate)" ] && deactivate

        source "$venv_dir"/bin/activate
    fi
fi
