#!/usr/bin/env bash

# Dispatch to the selected container library's software setup.
#
# If the first argument is given as "download", `pip` packages are
# pre-downloaded instead of being installed.
#
# If the first argument is given as "offline", the pre-downloaded
# packages are installed.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

if [ "$container_library" = apptainer ]; then
    source "$(get_curr_dir)"/outside-container-scripts/set_up_apptainer.sh "$@"
elif [ "$container_library" = docker ]; then
    source "$(get_curr_dir)"/outside-container-scripts/set_up_docker.sh "$@"
else
    echo "Unknown container library \"$container_library\"."
    pop_curr_file
    exit 1
fi

pop_curr_file
