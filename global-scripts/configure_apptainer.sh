#!/usr/bin/env bash

# Set up environment variables for Apptainer so that we write into
# storage where we know we have enough space.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/global_configuration.sh

mkdir -p "$apptainer_cache_dir"
export APPTAINER_CACHEDIR="$(mktemp -d -p "$apptainer_cache_dir")"

mkdir -p "$apptainer_tmp_dir"
export APPTAINER_TMPDIR="$(mktemp -d -p "$apptainer_tmp_dir")"
