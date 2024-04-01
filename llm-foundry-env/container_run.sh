#!/usr/bin/env bash

# Dispatch starting arbitrary commands using the selected container
# library.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global_configuration.sh

if [ "$container_library" = apptainer ]; then
    source "$_curr_dir"/outside-container-scripts/apptainer_run.sh
else
    echo "Unknown container library \"$container_library\"."
    exit 1
fi
