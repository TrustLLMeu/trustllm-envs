#!/usr/bin/env bash

# Configure the software environment used outside the container.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../../global_configuration.sh

# JSC machine activation steps
if [ "$machine_name" = jsc ] \
       || [ "$machine_name" = jwb ] \
       || [ "$machine_name" = jwc ] \
       || [ "$machine_name" = jrc ]; then
    source "$(get_curr_dir)"/../jsc/_activate.sh
elif [ "$machine_name" = bsc ] \
       || [ "$machine_name" = mn5 ]; then
    source "$(get_curr_dir)"/../bsc/_activate.sh
fi

source "$(get_curr_dir)"/../configuration.sh

# HuggingFace libraries cache configuration
source "$(get_curr_dir)"/../../global-scripts/configure_caches.sh

pop_curr_file
