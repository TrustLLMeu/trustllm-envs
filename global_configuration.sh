#!/usr/bin/env bash

# Configuration settings shared between all software environments.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/global-scripts/get_curr_file.sh "$_curr_file"

# Which machine we are running on. Currently supported options:
# - "local" (your local machine)
# - "jsc" (JUWELS Booster, JUWELS Cluster, JURECA-DC)
# - "bsc" (MareNostrum 5 ACC)
machine_name=jsc

# Set the following variables depending on the machine:
# - `root_project_dir`
# - `root_scratch_dir`
# - `project_name`
# - `container_library`
# - `cuda_compute_capability`
source "$(get_curr_dir)"/global-scripts/load_machine.sh "$machine_name"

# Directory where the environment's permanent files will be set up
# (e.g. code or included repositories).
base_project_dir="$root_project_dir"/"$project_name"/"$USER"

# Directory where the environment's non-permanent files (e.g. Python
# `venv`, container, ...) will be set up.
base_scratch_dir="$root_scratch_dir"/"$project_name"/"$USER"
# Where cache files are stored.
cache_dir="$base_scratch_dir"/.cache

# Which container library is used (overrides what's specified in
# `machine_data.csv`). Currently supported options:
# - "apptainer"
# - "docker"
# container_library=apptainer

# Name of Apptainer binary (used for overwriting it if necessary)
apptainer_bin="${apptainer_bin:-apptainer}"
docker_cmd="${docker_cmd:-}"
if [ -z "$docker_cmd" ]; then
    # Name of Docker command (used for overwriting it if necessary).
    # Use this to, e.g., add `sudo` to the command.
    docker_cmd=(docker)
fi

# Where Apptainer cache and temporary files will be stored
apptainer_cache_dir="$cache_dir"/apptainer
apptainer_tmp_dir="$cache_dir"/apptainer-tmp

# Root directory for caches of `pip`.
pip_cache_dir="$cache_dir"/pip

# Root directory for caches of Triton.
triton_cache_dir="$cache_dir"/triton

# Root directory for caches of PyTorch, such as for its Hub.
torch_cache_dir="$cache_dir"/torch

# Root directory for caches of various HuggingFace libraries.
hf_cache_dir="$cache_dir"/huggingface

# ---

pop_curr_file
