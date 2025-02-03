#!/usr/bin/env bash

# Overwrite all files to patch with their respective patches.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

for _patch_file_tuple in "${patched_files[@]}"; do
    _file_to_patch="$(echo "$_patch_file_tuple" | tr -s ':' | cut -d ':' -f 1)"
    _patched_file="$(echo "$_patch_file_tuple" | tr -s ':' | cut -d ':' -f 2)"

    cp "$_patched_file" "$_file_to_patch"
done

pop_curr_file
