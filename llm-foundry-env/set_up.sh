#!/usr/bin/env bash

# Dispatch to the selected container library's software setup.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global_configuration.sh

if [ "$container_library" = apptainer ]; then
    source "$_curr_dir"/outside-container-scripts/set_up_apptainer.sh
else
    echo "Unknown container library \"$container_library\"."
    exit 1
fi
