#!/usr/bin/env bash

# Build the Docker container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
if [ "$#" -gt 1 ] && [ "$1" = __inherit__ ]; then
    _curr_file="$2"
    _args=( "${@:3}" )
else
    _curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
    _args=( "$@" )
fi
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

if (("${DEBUG_TRUSTLLM_ENVS:-0}")); then
    printf '  in: %s\n    curr_file = %s\n' \
           "${BASH_SOURCE[0]:-${(%):-%x}}" \
           "$(get_curr_file)"
fi

# -----

_next_script="$(get_curr_dir)"/activate.sh
source "$_next_script" \
       __inherit__ "$_next_script"

# Strip the URI protocol.
_docker_image="$(echo "$docker_image_uri" | cut -d / -f 3-)"
"${docker_cmd[@]}" pull "$_docker_image"
"${docker_cmd[@]}" image tag "$_docker_image" "$docker_image_tag"

mkdir -p "$base_project_dir"
mkdir -p "$base_scratch_dir"
"${docker_cmd[@]}" \
    run \
    --network host --gpus all --ipc=host \
    --ulimit memlock=-1 --ulimit stack=67108864 \
    --mount type=bind,src="$HOME",dst="$HOME" \
    --mount type=bind,src="$_curr_dir"/../..,dst="$_curr_dir"/../.. \
    --mount type=bind,src="$base_project_dir",dst="$base_project_dir" \
    --mount type=bind,src="$base_scratch_dir",dst="$base_scratch_dir" \
    --name "$docker_build_container_name" -it \
    "$docker_image_tag" bash

pop_curr_file
