#!/usr/bin/env bash

# Start arbitrary commands from inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate.sh

if ! [ -f "$apptainer_file" ]; then
    echo 'Cannot find Apptainer container file; please run' \
         "\`bash outside-container-scripts/build_apptainer.sh" \
         "&& bash move_built_container_to_active.sh\`."
    pop_curr_file
    exit 1
fi
if ! [ -f "$scratch_dir"/triton-build-patch.py ]; then
    echo 'Cannot find necessary patch file; please run' \
         "\`bash outside-container-scripts/set_up_apptainer.sh\`."
    pop_curr_file
    exit 1
fi

# We assign to a variable again so Bash can do the quoted
# interpolation.
_curr_dir="$(get_curr_dir)"

apptainer run --nv --env PYTHONPATH= \
          --bind "$scratch_dir"/triton-build-patch.py:/usr/lib/python3/dist-packages/triton/common/build.py \
          "$apptainer_file" bash -c "
              source ${_curr_dir@Q}/../container-scripts/activate_container.sh \\
              && ${*@Q}
"

pop_curr_file
