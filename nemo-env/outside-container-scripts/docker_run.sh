#!/usr/bin/env bash

# Start arbitrary commands from inside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate.sh

"${docker_cmd[@]}" start "$docker_container_name"

# We assign to a variable again so Bash can do the quoted
# interpolation.
_curr_dir="$(get_curr_dir)"

# If the user does not supply an argument, drop them into an
# interactive shell. Similarly, if they try to execute `bash`, handle
# this specifically so we're still in the `venv`.
if [ "$#" -eq 0 ]; then
    _docker_args=( -it )
    args=(
        env
        BASH_ENV'='"$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        bash
        --init-file
        "$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        -i
    )
elif [ "$#" -gt 0 ] && [ "$(basename "$1")" = bash ]; then
    _docker_args=( -it )
    args=(
        env
        BASH_ENV'='"$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        bash
        --init-file
        "$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        "${@:2}"
    )
else
    _docker_args=()
    args=(
        env
        BASH_ENV'='"$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        bash
        --init-file
        "$(get_curr_dir)"/../container-scripts/activate_interactive_container.sh
        -c
        "${*@Q}"
    )
fi

"${docker_cmd[@]}" \
    exec \
    "${_docker_args[@]}" \
    --env USER="$USER" --env HOME="$HOME" \
    "$docker_container_name" \
    "${args[@]}"

pop_curr_file
