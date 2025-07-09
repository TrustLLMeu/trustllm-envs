#!/usr/bin/env bash

# This script contains configuration specific to the TGI
# environment. It is split into three sections:
#
# 1. configuration for the PROJECT directory, meaning long-term
#    storage such as for code repositories.
# 2. configuration for the SCRATCH directory, meaning short-term
#    storage such as for binaries or caches.
# 3. configuration for this directory, so that it's easy to make all
#    supercomputer-specific scripts refer to the same file.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

env_name=tgi

# ---

# PROJECT directory (long-term storage)

# `base_project_dir` is configured in `../global_configuration.sh`.
project_dir="$base_project_dir"/"$env_name"

# Where external repositories will be installed.
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
# For example, this would clone a repo at tag v0.0.1 and do a standard
# `pip install -e .`:
# repos+=( 'https://github.com/github/example-repo.git v0.0.1' )

# ---

# SCRATCH directory (short-term storage)

# `base_scratch_dir` is configured in `../global_configuration.sh`.
scratch_dir="$base_scratch_dir"/"$env_name"

# Directory that will contain the Python `venv`.
venv_dir="$scratch_dir"/env_"$(uname -m)"

# Which container to build.
docker_image_uri='docker://ghcr.io/huggingface/text-generation-inference:3.3.4'
# Which file to build the container in. The default settings
# automatically grab the information from the tail of the URI.
apptainer_build_file="$scratch_dir"/apptainers/build/tgi_"$(basename "$docker_image_uri" | tr ':' '_')"_"$(uname -m)".sif
docker_image_tag=tgi_"$(basename "$docker_image_uri")"_"$(uname -m)"
docker_build_container_name=build_tgi_"$(basename "$docker_image_uri" | tr ':' '_')"_"$(uname -m)"
# Which container to use. Ideally keep this different from the above
# build paths so the actively used container is not overwritten by
# accident.
apptainer_file="$scratch_dir"/apptainers/tgi_"$(basename "$docker_image_uri" | tr ':' '_')"_"$(uname -m)".sif
docker_container_name=tgi_"$(basename "$docker_image_uri" | tr ':' '_')"_"$(uname -m)"
# Pre-dowloaded image used for offline building if requested. The
# default setting uses the same location as `apptainer_build_file`,
# with the `sif` file ending replaced by `tar`.
apptainer_offline_build_file="$(dirname "$apptainer_build_file")"/"$(basename "$apptainer_build_file" .sif)"_"$(uname -m)".tar

# Where `pip` packages will be stored/looked for for offline
# installation.
pip_offline_dir="$scratch_dir"/pip-offline

# Array of files to patch in the container. The two entries (file to
# patch inside container, patched file outside of container) are
# separated by colons. Should be absolute paths.
patched_files=()
# File to patch and patched file locations; separated by colons.
# For example, this would patch the file located inside the container
# at `/inside-container/my-file` and create a patched version at
# `/outside-container/my-file-patched` (which will be appropriately
# mapped onto the container):
# patched_files+=( '/inside-container/my-file:/outside-container/my-file-patched' )

# Array of repository URIs that point to forks. This is used to update
# a local clone's remote URI. Any repository URIs that still point to
# upstream will instead be pointed to the fork's URI if necessary.
# Note that this functionality relies on repositories all having
# different names.
forked_repo_uris=()

# ---

pop_curr_file
