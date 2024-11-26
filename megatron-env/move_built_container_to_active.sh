#!/usr/bin/env bash

# Move the container from its build to its active usage location.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configuration.sh

if [ "$container_library" = apptainer ]; then
    mkdir -p "$(dirname "$apptainer_file")"
    mv -i "$apptainer_build_file" "$apptainer_file"
elif [ "$container_library" = docker ]; then
    # Only remove old container if the new one actually exists.
    if [ -n "$("${docker_cmd[@]}" container ls --all -q -f name='^'"$docker_container_name"'$')" ] \
           && [ -n "$("${docker_cmd[@]}" container ls --all -q -f name='^'"$docker_build_container_name"'$')" ]; then
        "${docker_cmd[@]}" container rm "$docker_container_name"
    fi
    "${docker_cmd[@]}" container rename "$docker_build_container_name" \
           "$docker_container_name"
else
    echo "Unknown container library \"$container_library\"."
    pop_curr_file
    exit 1
fi

pop_curr_file
