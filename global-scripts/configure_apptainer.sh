#!/usr/bin/env bash

# Set up environment variables for Apptainer so that we write into
# storage where we know we have enough space.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

mkdir -p "$apptainer_cache_dir"
export APPTAINER_CACHEDIR="$apptainer_cache_dir"
# Also export old name for backward-compatibility.
export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"

mkdir -p "$apptainer_tmp_dir"
export APPTAINER_TMPDIR="$apptainer_tmp_dir"
# Also export old name for backward-compatibility.
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"

pop_curr_file
