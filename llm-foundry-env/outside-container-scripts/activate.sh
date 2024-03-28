#!/usr/bin/env bash

# Configure the software environment used outside the container.

set -euo pipefail

module purge
module load Stages/2024
module load GCC Apptainer-Tools NCCL

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"
source "$curr_dir"/../configuration.sh

# HuggingFace libraries cache configuration
source "$curr_dir"/../../configure_hf_caches.sh
