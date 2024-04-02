#!/usr/bin/env bash

# Set up environment variables for HuggingFace libraries so that we
# use offline mode. This is necessary for supercomputer systems that
# do not have internet access on compute nodes.

set -euo pipefail

# Put HuggingFace libraries into offline mode.
export HF_DATASETS_OFFLINE=1
export HF_EVALUATE_OFFLINE=1
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
