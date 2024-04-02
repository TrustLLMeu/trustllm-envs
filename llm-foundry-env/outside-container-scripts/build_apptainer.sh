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

apptainer pull "$apptainer_build_file" "$docker_image_uri"

pop_curr_file
