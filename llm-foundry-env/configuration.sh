#!/usr/bin/env bash

# This script contains configuration specific to the llm-foundry
# environment. It is split into three sections:
#
# 1. configuration for the PROJECT directory, meaning long-term
#    storage such as for code repositories.
# 2. configuration for the SCRATCH directory, meaning short-term
#    storage such as for binaries, preprocessed data, or model
#    checkpoints.
# 3. configuration for this directory, so that it's easy to make all
#    supercomputer-specific scripts refer to the same file.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global_configuration.sh

env_name=llm-foundry

# ---

# PROJECT directory (long-term storage)

# `base_project_dir` is configured in `../global_configuration.sh`.
project_dir="$base_project_dir"/"$env_name"

# Where external repositories will be installed (such as llm-foundry
# itself).
repo_dir="$project_dir"/repos
# List of repositories to clone and naïvely `pip install` (i.e., `cd`
# into the repo, then execute `pip install -e .`, optionally with
# extra features as specified in `install_features`).
declare -A repos
# Repository to clone and additional `pip install` features to install
# (set as empty string (`''`) for default features, see example
# below).
# Data processing/format library.
repos['https://github.com/mosaicml/streaming.git']=''
# Trainer library.
repos['https://github.com/mosaicml/composer.git']='[nlp,tensorboard,wandb]'
# Main framework.
# The feature "gpu" is the same as "gpu-flash2", but we currently keep
# the latter explicit specification because that is a very recent
# change.
# This would execute `python -m pip install -e '.[gpu-flash2,tensorboard]'`
repos['https://github.com/mosaicml/llm-foundry.git']='[gpu-flash2,tensorboard]'
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

# Which container to build.
# container_uri='docker://docker.io/mosaicml/llm-foundry:2.2.1_cu121_flash2-latest'
# TODO below has flash attn too, so use that instead
container_uri='docker://docker.io/mosaicml/pytorch:2.2.1_cu121-python3.11-ubuntu20.04'
# Where to store the container.
container_file="$scratch_dir"/llm-foundry-latest.sif

# ---

# This directory

# Container script used for data preprocessing.
preprocessing_script="$_curr_dir"/container-scripts/preprocess_data_container.sh

# Container script used for parallel data preprocessing.
parallel_preprocessing_script="$_curr_dir"/container-scripts/preprocess_data_container_parallel.sh

# Container script used for training runs.
training_script="$_curr_dir"/container-scripts/run_training_container.sh
