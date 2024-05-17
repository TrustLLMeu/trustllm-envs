#!/usr/bin/env bash

# Configuration settings shared between all software environments.

set -euo pipefail

# Directory where the environment's permanent files will be set up
# (e.g. code or included repositories).
base_project_dir=/p/project/trustllm-eu/"$USER"

# Directory where the environment's non-permanent files (e.g. Python
# `venv`, container, ...) will be set up.
base_scratch_dir=/p/scratch/trustllm-eu/"$USER"
# Where cache files are stored.
cache_dir="$base_scratch_dir"/.cache

# Which container library is used. Currently supported options:
# - "apptainer"
container_library=apptainer

# Where Apptainer cache and temporary files will be stored
apptainer_cache_dir="$cache_dir"/apptainer
apptainer_tmp_dir="$cache_dir"/apptainer-tmp

# Root directory for caches of PyTorch, such as for its Hub.
torch_cache_dir="$cache_dir"/torch

# Root directory for caches of various HuggingFace libraries.
hf_cache_dir="$cache_dir"/huggingface

# Root directory for caches of Triton.
triton_cache_dir="$cache_dir"/triton