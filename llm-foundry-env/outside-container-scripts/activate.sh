#!/usr/bin/env bash

# Configure the software environment used outside the container.

set -euo pipefail

module purge
module load Stages/2024
module load GCC Apptainer-Tools NCCL

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../configuration.sh

# HuggingFace libraries cache configuration
source "$_curr_dir"/../../global-scripts/configure_hf_caches.sh
