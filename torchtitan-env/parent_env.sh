#!/usr/bin/env bash

# This script contains a path to the parent environment of the
# TorchTitan environment.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

# Directory of this environment.
curr_env_dir="$(get_curr_dir)"

# Directory of environment this one bases on.
parent_env_dir="$(get_curr_dir)"/../pytorch-env

pop_curr_file
