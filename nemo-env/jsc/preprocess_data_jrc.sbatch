#!/usr/bin/env bash

# Preprocess data on JURECA DC.

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128  # 128 physical cores per node.
#SBATCH --hint=nomultithread  # Use only physical CPU cores.
#SBATCH --time=00:20:00
#SBATCH --account=trustllm-eu
# Use `dc-cpu-devel` for debugging, `dc-cpu` for "normal" jobs,
# `dc-cpu-bigmem` for nodes with higher memory, and `dc-cpu-large` for
# jobs on more than 256 nodes.
#SBATCH --partition=dc-cpu-devel

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

export NUM_WORKERS="$SRUN_CPUS_PER_TASK"

export INPUT_DATA_FILE="$root_scratch_dir"/"$project_name"/example-data/tiny-c4-10k.jsonl

export TOKENIZER_VOCAB_FILE="$root_scratch_dir"/"$project_name"/example-data/gpt2-tokenizer/vocab.json
export TOKENIZER_MERGE_FILE="$root_scratch_dir"/"$project_name"/example-data/gpt2-tokenizer/merges.txt
# The SentencePiece tokenizer is not used by default in the example,
# but we include and export it here just so it's available when
# desired.
export TOKENIZER_MODEL_FILE="$root_scratch_dir"/"$project_name"/example-data/t5-small-tokenizer/spiece.model

export OUTPUT_DATA_PREFIX="$data_dir"/my-tiny-c4-gpt2-tok/val
# export OUTPUT_DATA_PREFIX="$data_dir"/my-tiny-c4-t5-small-tok/val

srun bash "$(get_curr_dir)"/../container_run.sh \
     bash "$preprocessing_script"

pop_curr_file
