#!/usr/bin/env bash

# This script contains configuration specific to the NeMo environment.
# It is split into three sections:
#
# 1. configuration for the PROJECT directory, meaning long-term
#    storage such as for code repositories.
# 2. configuration for the SCRATCH directory, meaning short-term
#    storage such as for binaries, preprocessed data, or model
#    checkpoints.
# 3. configuration for this directory, so that it's easy to make all
#    supercomputer-specific scripts refer to the same file.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

env_name=nemo

# ---

# PROJECT directory (long-term storage)

# `base_project_dir` is configured in `../global_configuration.sh`.
project_dir="$base_project_dir"/"$env_name"

# Where external repositories will be installed (such as NeMo itself).
ext_repo_dir="$project_dir"/repos
# List of repositories to clone and naïvely `pip install` (i.e., `cd`
# into the repo, then execute `pip install -e .`, optionally with
# extra features as specified in `install_features`).
declare -A repos
# Repository to clone and additional `pip install` features to install
# (set as empty string (`''`) for default features, see example
# below).
# Backend library.
repos['https://github.com/NVIDIA/Megatron-LM.git']=''
# Main framework.
# This would execute `python -m pip install -e '.[all]'`
repos['https://github.com/NVIDIA/NeMo.git']='[all]'
# Launcher library.
repos['https://github.com/NVIDIA/NeMo-Megatron-Launcher.git']=''
# Alignment library.
repos['https://github.com/NVIDIA/NeMo-Aligner.git']=''
# For example, this would clone a repo and do a standard
# `pip install -e .`:
# repos['https://github.com/github/example-repo.git']=''

# ---

# SCRATCH directory (short-term storage)

# `base_scratch_dir` is configured in `../global_configuration.sh`.
scratch_dir="$base_scratch_dir"/"$env_name"

# Directory that will contain the Python `venv`.
venv_dir="$scratch_dir"/env

# Where to store preprocessed datasets.
data_dir="$scratch_dir"/data

# Where to store model checkpoints.
checkpoint_dir="$scratch_dir"/experiments

# Which container to build.
docker_image_uri='docker://nvcr.io/nvidia/nemo:24.01.01.framework'
# Which file to build the container in. The default settings
# automatically grab the information from the tail of the URI.
apptainer_build_file="$scratch_dir"/apptainers/build/"$(basename "$docker_image_uri" | tr ':' '_')".sif
# Which container to use. Ideally keep this different from the above
# build paths so the actively used container is not overwritten by
# accident.
apptainer_file="$scratch_dir"/apptainers/"$(basename "$docker_image_uri" | tr ':' '_')".sif

# ---

# This directory

# Container script used for data preprocessing.
preprocessing_script="$(get_curr_dir)"/container-scripts/preprocess_data_container.sh

# Container script used for training runs.
training_script="$(get_curr_dir)"/container-scripts/run_training_container.sh

# Container script used for HuggingFace training runs.
hf_training_script="$(get_curr_dir)"/container-scripts/run_hf_training_container.sh

# ---

pop_curr_file
