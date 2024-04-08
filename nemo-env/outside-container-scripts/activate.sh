#!/usr/bin/env bash

# Configure the software environment used outside the container.

set -euo pipefail

module purge
module load Stages/2024
module load GCC Apptainer-Tools NCCL

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

# HuggingFace libraries cache configuration
source "$(get_curr_dir)"/../../global-scripts/configure_hf_caches.sh

pop_curr_file
