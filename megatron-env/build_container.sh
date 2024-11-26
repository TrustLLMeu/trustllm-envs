#!/usr/bin/env bash

# Dispatch to the selected container library's build command.
#
# If the first argument is given as "offline", the container is built
# from a pre-downloaded container image.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

if [ "$container_library" = apptainer ]; then
    source "$(get_curr_dir)"/outside-container-scripts/build_apptainer.sh "$@"
elif [ "$container_library" = docker ]; then
    source "$(get_curr_dir)"/outside-container-scripts/build_docker.sh "$@"
else
    echo "Unknown container library \"$container_library\"."
    pop_curr_file
    exit 1
fi

echo "Please don't forget to move the container to the appropriate location" \
     "using \`bash $(get_curr_dir)/move_built_container_to_active.sh\`." \
     "Be careful, since this will overwrite the old active container."

pop_curr_file
