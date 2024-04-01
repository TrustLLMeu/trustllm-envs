#!/usr/bin/env bash

# Start the software setup done inside the container.

set -euo pipefail

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"
source "$curr_dir"/../outside-container-scripts/activate.sh

apptainer run --nv --env PYTHONPATH= "$container_file" \
          bash "$curr_dir"/../container-scripts/set_up_container.sh
