#!/usr/bin/env bash

# Build the Apptainer container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate.sh

source "$(get_curr_dir)"/../../global-scripts/configure_apptainer.sh

mkdir -p "$(dirname "$apptainer_build_file")"

if [ "$#" -gt 0 ] && [ "$1" = offline ]; then
    apptainer_cache_build_file="$(dirname "$apptainer_build_file")"/"$(basename "$apptainer_build_file" .sif)".tar

    if ! [ -f "$apptainer_cache_build_file" ]; then
        echo 'Container has not been pre-downloaded for offline building.' \
             "Please execute place it at \`$apptainer_cache_build_file\`."
    fi

    "$apptainer_bin" build "$apptainer_build_file" \
                     docker-archive://"$apptainer_cache_build_file"
else
    "$apptainer_bin" pull "$apptainer_build_file" "$docker_image_uri"
fi

pop_curr_file
