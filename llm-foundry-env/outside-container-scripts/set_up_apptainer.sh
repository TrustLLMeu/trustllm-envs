#!/usr/bin/env bash

# Start the software setup done inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate.sh

apptainer run --nv --env PYTHONPATH= "$apptainer_file" \
          bash "$(get_curr_dir)"/../container-scripts/set_up_container.sh

pop_curr_file
