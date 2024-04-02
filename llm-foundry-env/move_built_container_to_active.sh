#!/usr/bin/env bash

# Move the container from its build to its active usage location.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

if [ "$container_library" = apptainer ]; then
    mv -i "$apptainer_build_file" "$apptainer_file"
else
    echo "Unknown container library \"$container_library\"."
    pop_curr_file
    exit 1
fi

pop_curr_file
