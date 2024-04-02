#!/usr/bin/env bash

# Set up environment variables for HuggingFace libraries so that we
# write into storage where we know we have enough space.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../global_configuration.sh

# HuggingFace libraries cache configuration
mkdir -p "$hf_cache_dir"
# We set some stuff multiple times here just to be super safe.
export HF_HOME="$hf_cache_dir"
export HF_ASSETS_CACHE="$hf_cache_dir"/assets
export HF_DATASETS_CACHE="$hf_cache_dir"/datasets
export HF_EVALUATE_CACHE="$hf_cache_dir"/evaluate
export HF_HUB_CACHE="$hf_cache_dir"/hub
export HF_METRICS_CACHE="$hf_cache_dir"/metrics
export HF_MODULES_CACHE="$hf_cache_dir"/modules
# Backward compatibility
export HUGGINGFACE_ASSETS_CACHE="$hf_cache_dir"/assets
export HUGGINGFACE_HUB_CACHE="$hf_cache_dir"/hub
# This one spits annoying deprecation warnings about using `HF_HOME`
# even though we set that one to the same value. Assuming we always
# use a recent enough `transformers` version, it should be fine to
# leave this commented out.
# export TRANSFORMERS_CACHE="$hf_cache_dir"/hub

pop_curr_file
