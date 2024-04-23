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
# Array of repositories and their tag to clone and naïvely `pip
# install` (i.e., `cd` into the repo, then execute `pip install -e .`,
# optionally with extra features as specified in the value for each
# repo key). The three entries (repository, tag, `pip install`
# features) are separated by spaces.
repos=()
# Repository to clone, the commit to clone, and additional `pip
# install` features to install (leave out for default features, see
# example below); separated by spaces.
# Backend library. Commit specified in `NeMo/Dockerfile` (and checked
# using recursive `diff` in old NeMo container).
repos+=( 'https://github.com/NVIDIA/Megatron-LM.git ad53b1e38689a0ceed75ade7821f4e6c7554abb4' )
# Main framework. Commit taken from old NeMo container
# `/opt/NeMo/.git/logs/HEAD`.
# This would execute `python -m pip install -e '.[all]'`
repos+=( 'https://github.com/NVIDIA/NeMo.git 8f3855f241099a83b405d2057998d628789ec73b [all]' )
# Launcher library. Commit taken from old NeMo container
# `/opt/NeMo-Megatron-Launcher/.git/logs/HEAD`.
# This one is hardcoded to execute `python -m pip install -r
# requirements.txt` because it does not support the other installation
# method.
repos+=( 'https://github.com/NVIDIA/NeMo-Framework-Launcher.git 6cdd33614134879048e13ae9f1d180f50d202a3d' )
# Alignment library. Commit taken from old NeMo container
# `/opt/NeMo-Aligner/.git/logs/HEAD`.
repos+=( 'https://github.com/NVIDIA/NeMo-Aligner.git 2de2f184fcc7c9bafcdd871f2657f74ef43ea3df' )
# For example, this would clone a repo and do a standard
# `pip install -e .`:
# repos+=( 'https://github.com/github/example-repo.git v0.0.1' )

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
docker_image_uri='docker://nvcr.io/nvidia/pytorch:24.03-py3'
# Which file to build the container in. The default settings
# automatically grab the information from the tail of the URI.
apptainer_build_file="$scratch_dir"/apptainers/build/nemo_"$(basename "$docker_image_uri" | tr ':' '_')".sif
# Which container to use. Ideally keep this different from the above
# build paths so the actively used container is not overwritten by
# accident.
apptainer_file="$scratch_dir"/apptainers/nemo_"$(basename "$docker_image_uri" | tr ':' '_')".sif

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
