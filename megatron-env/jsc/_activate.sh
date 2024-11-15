#!/usr/bin/env bash

# Partially configure the software environment used outside the
# container for JSC machines.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../../global_configuration.sh

if [ "$SYSTEMNAME" = juwelsbooster ] \
       || [ "$SYSTEMNAME" = juwels ] \
       || [ "$SYSTEMNAME" = jurecadc ]; then
    module purge
    module load Stages/2024
    module load GCC
    if [ "$container_library" = apptainer ]; then
        # Handle partitions without Apptainer-Tools module.
        module try-load Apptainer-Tools
        if ! [ "$(command -v apptainer)" ]; then
            echo "Could not find Apptainer on JSC machine."
            exit 1
        fi
    fi
fi

pop_curr_file
