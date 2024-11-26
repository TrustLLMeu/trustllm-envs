#!/usr/bin/env bash

# Load configuration variables for the specified machine from
# `machine_data.csv`.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/get_curr_file.sh "$_curr_file"

machine_name="$1"

_delim=':'

while read -r line; do
    _curr_name="$(echo "$line" | cut -d "$_delim" -f 1)"
    if [ "$_curr_name" = "$machine_name" ]; then
        root_project_dir="$(echo "$line" | cut -d "$_delim" -f 2)"
        # Replace potential tilde prefix for home directory.
        root_project_dir="${root_project_dir/#\~/"$HOME"}"
        root_scratch_dir="$(echo "$line" | cut -d "$_delim" -f 3)"
        # Replace potential tilde prefix for home directory.
        root_scratch_dir="${root_scratch_dir/#\~/"$HOME"}"
        project_name="$(echo "$line" | cut -d "$_delim" -f 4)"
        container_library="$(echo "$line" | cut -d "$_delim" -f 5)"
        cuda_compute_capability="$(echo "$line" | cut -d "$_delim" -f 6)"
    fi
done < "$(get_curr_dir)"/../machine_data.csv

pop_curr_file
