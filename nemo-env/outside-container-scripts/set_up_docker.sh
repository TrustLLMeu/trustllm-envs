#!/usr/bin/env bash

# Start the software setup done inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate.sh

if [ -z "$("${docker_cmd[@]}" container ls --all -q -f name='^'"$docker_container_name"'$')" ]; then
    echo 'Cannot find Docker container; please run' \
         "\`nice bash build_container.sh" \
         "&& bash move_built_container_to_active.sh\`."
    pop_curr_file
    exit 1
fi

"${docker_cmd[@]}" start "$docker_container_name"

# Make backup of files to patch. We'll overwrite the original files
# further below.
"${docker_cmd[@]}" \
    exec \
    --env USER="$USER" --env HOME="$HOME" \
    -it "$docker_container_name" \
    bash "$(get_curr_dir)"/../container-scripts/make_initial_patch_backups.sh

"${docker_cmd[@]}" \
    exec \
    --env USER="$USER" --env HOME="$HOME" \
    -it "$docker_container_name" \
    bash "$(get_curr_dir)"/../container-scripts/set_up_container.sh "$@"

# Overwrite patched files.
"${docker_cmd[@]}" \
    exec \
    --env USER="$USER" --env HOME="$HOME" \
    -it "$docker_container_name" \
    bash "$(get_curr_dir)"/../container-scripts/overwrite_with_patches.sh

pop_curr_file
