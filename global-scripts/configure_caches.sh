#!/usr/bin/env bash

# Set up caching environment variables so that we write into storage
# where we know we have enough space.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configure_triton_caches.sh
source "$(get_curr_dir)"/configure_torch_caches.sh
source "$(get_curr_dir)"/configure_hf_caches.sh

pop_curr_file
