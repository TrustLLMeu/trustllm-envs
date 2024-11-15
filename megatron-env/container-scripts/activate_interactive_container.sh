#!/usr/bin/env bash

# Configure the software environment used inside the container, and
# set it up for interactive usage.

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/activate_container.sh

pop_curr_file

# Undo our safe scripting options to improve interactive use inside
# the container.
set +euo pipefail
