#!/usr/bin/env bash

# Preprocess data on JUWELS Cluster.

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48  # 48 physical cores per node.
#SBATCH --hint=nomultithread  # Use only physical CPU cores.
#SBATCH --time=00:20:00
#SBATCH --account=trustllm-eu
# Use `devel` for debugging, `batch` for "normal" jobs, `mem192` for
# nodes with higher memory, and `large` for jobs on more than 256
# nodes.
#SBATCH --partition=devel

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

export INPUT_DATA_FILE=/p/scratch/trustllm-eu/example-data/tiny-c4-10k.jsonl
export TOKENIZER_DIR=/p/scratch/trustllm-eu/example-data/gpt2-tokenizer
export OUTPUT_DATA_DIR="$data_dir"/my-tiny-c4-gpt2-tok/val

srun bash "$(get_curr_dir)"/../container_run.sh \
     bash "$preprocessing_script"

pop_curr_file
