#!/usr/bin/env bash

# Start arbitrary commands from inside the container.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/outside-container-scripts/activate.sh

apptainer run --nv --env PYTHONPATH= \
          --bind "$scratch_dir"/triton-build-patch.py:/usr/lib/python3/dist-packages/triton/common/build.py \
          "$apptainer_file" bash -c "
              source ${_curr_dir@Q}/container-scripts/activate_container.sh \
              && ${*@Q}
"
