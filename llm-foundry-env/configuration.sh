#!/usr/bin/env bash

# This script contains configuration specific to the LLM Foundry
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

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

env_name=llm-foundry

# ---

# PROJECT directory (long-term storage)

# `base_project_dir` is configured in `../global_configuration.sh`.
project_dir="$base_project_dir"/"$env_name"

# Where external repositories will be installed (such as LLM Foundry
# itself).
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
# Data processing/format library. Latest version specified in
# `llm-foundry/setup.py`.
repos+=( 'https://github.com/mosaicml/streaming.git v0.8.0' )
# MoE library. Latest version specified in `llm-foundry/setup.py`.
repos+=( 'https://github.com/databricks/megablocks.git v0.5.1' )
# Trainer library. Latest version specified in `llm-foundry/setup.py`.
repos+=( 'https://github.com/mosaicml/composer.git v0.23.5 [nlp,tensorboard,wandb]' )
# Main framework. Latest release version.
# The feature "gpu" is the same as "gpu-flash2", but we currently keep
# the latter explicit specification because that is a very recent
# change.
# This would execute `python -m pip install -e '.[gpu-flash2,tensorboard]'`
repos+=( 'https://github.com/mosaicml/llm-foundry.git v0.11.0 [gpu-flash2,megablocks,openai,tensorboard]' )
# For example, this would clone a repo at tag v0.0.1 and do a standard
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
docker_image_uri='docker://docker.io/mosaicml/pytorch:2.3.1_cu121-python3.11-ubuntu20.04'
# Which file to build the container in. The default settings
# automatically grab the information from the tail of the URI.
apptainer_build_file="$scratch_dir"/apptainers/build/llm-foundry_"$(basename "$docker_image_uri" | tr ':' '_')".sif
# Which container to use. Ideally keep this different from the above
# build paths so the actively used container is not overwritten by
# accident.
apptainer_file="$scratch_dir"/apptainers/llm-foundry_"$(basename "$docker_image_uri" | tr ':' '_')".sif
# Pre-dowloaded image used for offline building if requested. The
# default setting uses the same location as `apptainer_build_file`,
# with the `sif` file ending replaced by `tar`.
apptainer_offline_build_file="$(dirname "$apptainer_build_file")"/"$(basename "$apptainer_build_file" .sif)".tar

# Where `pip` packages will be stored/looked for for offline
# installation.
pip_offline_dir="$scratch_dir"/pip-offline

# ---

# This directory

# Container script used for data preprocessing.
preprocessing_script="$(get_curr_dir)"/container-scripts/preprocess_data_container.sh

# Container script used for parallel data preprocessing.
parallel_preprocessing_script="$(get_curr_dir)"/container-scripts/preprocess_data_container_parallel.sh

# Container script used for training runs.
training_script="$(get_curr_dir)"/container-scripts/run_training_container.sh

# ---

pop_curr_file
