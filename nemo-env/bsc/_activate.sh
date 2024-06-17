#!/usr/bin/env bash

# Partially configure the software environment used outside the
# container for BSC machines.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../../global_configuration.sh

module purge
if [ "$container_library" = apptainer ]; then
    module try-load singularity
    if ! [ "$(command -v singularity)" ]; then
        echo "Could not find Singularity on BSC machine."
        exit 1
    fi
    apptainer_bin=singularity
fi

pop_curr_file
