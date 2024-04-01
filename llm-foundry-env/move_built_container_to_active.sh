#!/usr/bin/env bash

# Move the container from its build to its active usage location.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../configuration.sh

if [ "$container_library" = apptainer ]; then
    mv -i "$apptainer_build_file" "$apptainer_file"
else
    echo "Unknown container library \"$container_library\"."
    exit 1
fi
