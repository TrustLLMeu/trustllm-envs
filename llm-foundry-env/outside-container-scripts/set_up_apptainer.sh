#!/usr/bin/env bash

# Start the software setup done inside the container.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../outside-container-scripts/activate.sh

apptainer run --nv --env PYTHONPATH= "$apptainer_file" \
          bash "$_curr_dir"/../container-scripts/set_up_container.sh
