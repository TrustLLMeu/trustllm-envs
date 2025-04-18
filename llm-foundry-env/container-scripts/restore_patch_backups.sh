#!/usr/bin/env bash

# Try to restore a backup file suffixed with ".bak" for each file to
# patch, overwriting the location not suffixed with ".bak". If a
# backup file does not exist, the script will ignore it.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

for _patch_file_tuple in "${patched_files[@]}"; do
    _file_to_patch="$(echo "$_patch_file_tuple" | tr -s ':' | cut -d ':' -f 1)"

    if [ -f "$_file_to_patch".bak ]; then
        # Assume we have a writable container if the original file's
        # backup exists.
        cp "$_file_to_patch".bak "$_file_to_patch"
    fi
done

pop_curr_file
