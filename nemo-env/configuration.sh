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
# Backend library. Commit found manually by checking using recursive
# `diff` in old NeMo container (nvcr.io/nvidia/nemo:24.05). The exact
# commit couldn't be reproduced.
repos+=( 'https://github.com/NVIDIA/Megatron-LM.git a645f89671be698612170539f2089dc15db66a80' )
# Main framework. Commit taken from old NeMo container
# `/opt/NeMo/.git/logs/HEAD`.
# This would execute `python -m pip install -e '.[all]'`
repos+=( 'https://github.com/TrustLLMeu/NeMo.git 92ca94c0fa8b54df8d0cf38338d27261a49725a1 [all]' )
# Launcher library. Commit taken from old NeMo container
# `/opt/NeMo-Framework-Launcher/.git/logs/HEAD`.
# This one is hardcoded to execute `python -m pip install -r
# requirements.txt` because it does not support the other installation
# method.
repos+=( 'https://github.com/NVIDIA/NeMo-Framework-Launcher.git 599ecfcbbd64fd2de02f2cc093b1610d73854022' )
# Alignment library. Commit taken from old NeMo container
# `/opt/NeMo-Aligner/.git/logs/HEAD` with adjustments after manually
# checking required changes (container's commit doesn't exist
# anymore).
repos+=( 'https://github.com/NVIDIA/NeMo-Aligner.git 0baba9939fef0fd37b89d019a9b6ef4fdfdc2c65' )
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
docker_image_uri='docker://nvcr.io/nvidia/pytorch:24.05-py3'
# Which file to build the container in. The default settings
# automatically grab the information from the tail of the URI.
apptainer_build_file="$scratch_dir"/apptainers/build/nemo_"$(basename "$docker_image_uri" | tr ':' '_')".sif
# Which container to use. Ideally keep this different from the above
# build paths so the actively used container is not overwritten by
# accident.
apptainer_file="$scratch_dir"/apptainers/nemo_"$(basename "$docker_image_uri" | tr ':' '_')".sif
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
parallel_preprocessing_script="$(get_curr_dir)"/container-scripts/preprocess_data_parallel_container.sh

# Container script used for training runs.
training_script="$(get_curr_dir)"/container-scripts/run_training_container.sh

# Container script used for muTransfer runs.
mup_training_script="$(get_curr_dir)"/container-scripts/run_mutransfer_training_container.sh

# Container script used for HuggingFace training runs.
hf_training_script="$(get_curr_dir)"/container-scripts/run_hf_training_container.sh

# ---

pop_curr_file
