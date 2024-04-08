#!/usr/bin/env bash

# Set up environment variables for PyTorch so that we write into
# storage where we know we have enough space.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

# PyTorch cache configuration
mkdir -p "$torch_cache_dir"

export TORCH_HOME="$torch_cache_dir"/hub
export TORCH_EXTENSIONS_DIR="$torch_cache_dir"/torch_extensions

pop_curr_file
