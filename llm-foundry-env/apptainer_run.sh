#!/usr/bin/env bash

# Start arbitrary commands from inside the container.

set -euo pipefail

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"
source "$curr_dir"/outside-container-scripts/activate.sh

apptainer run --nv --env PYTHONPATH= \
          --bind "$scratch_dir"/triton-build-patch.py:/usr/lib/python3/dist-packages/triton/common/build.py \
          "$container_file" bash -c "
              source ${_curr_dir@Q}/container-scripts/activate_container.sh \
              && ${*@Q}
"
