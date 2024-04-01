#!/usr/bin/env bash

# Start arbitrary commands from inside the container.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/outside-container-scripts/activate.sh

if ! [ -f "$apptainer_file" ]; then
    echo 'Cannot find Apptainer container file; please run' \
         "\`bash outside-container-scripts/build_apptainer.sh" \
         "&& bash move_built_container_to_active.sh\`."
    exit 1
fi
if ! [ -f "$scratch_dir"/triton-build-patch.py ]; then
    echo 'Cannot find necessary patch file; please run' \
         "\`bash outside-container-scripts/set_up_apptainer.sh\`."
    exit 1
fi

apptainer run --nv --env PYTHONPATH= \
          --bind "$scratch_dir"/triton-build-patch.py:/usr/lib/python3/dist-packages/triton/common/build.py \
          "$apptainer_file" bash -c "
              source ${_curr_dir@Q}/container-scripts/activate_container.sh \\
              && ${*@Q}
"
