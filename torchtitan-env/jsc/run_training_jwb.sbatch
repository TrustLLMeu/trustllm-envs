#!/usr/bin/env bash

# Run a model training on JUWELS Booster.

#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48  # 48 physical cores per node.
#SBATCH --threads-per-core=1  # Use only physical CPU cores.
#SBATCH --gres=gpu:4
#SBATCH --time=00:20:00
#SBATCH --account=trustllm-eu
# Use `develbooster` for debugging, `booster` for "normal" jobs, and
# `largebooster` for jobs on more than 256 nodes.
#SBATCH --partition=develbooster

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

export MASTER_ADDR="$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)"
if [ "$SYSTEMNAME" = juwelsbooster ] \
       || [ "$SYSTEMNAME" = juwels ] \
       || [ "$SYSTEMNAME" = jurecadc ] \
       || [ "$SYSTEMNAME" = jusuf ]; then
    # Allow communication over InfiniBand cells on JSC machines.
    MASTER_ADDR="$MASTER_ADDR"i
fi
export MASTER_PORT=54123

export GLOO_SOCKET_IFNAME=ib0
export NCCL_IB_TIMEOUT=20
# Is slower even with sequence parallelism.
# export CUDA_DEVICE_MAX_CONNECTIONS=1

export DEVICES_PER_NODE=4

export GPUS_PER_REPLICA=4

export NUM_NODES="$SLURM_JOB_NUM_NODES"
export RDZV_ID="$SLURM_JOB_ID"

# We have 48 physical CPU cores on JUWELS Booster nodes, so configure
# 11 active data workers per GPU in total (that is, for the
# "train" and "validation" split; we exclude the "test" split here);
# this leaves one CPU for the main process.
export TRAIN_NUM_WORKERS=11

# These prefixes are slightly different from the ones for data
# preprocessing. These also include the JSON key used for querying the
# text (usually "text") and the hierarchical level of processing
# (usually "document").
# In the usual case, the following conversion example should work:
#
# ```
# # This variable is given for preprocessing
# OUTPUT_DATA_PATH="$data_dir"/my-data/train
# # This variable is given for training
# TRAIN_DATA_PATH="$data_dir"/my-data/train_text_document
# ```
#
# If you are unsure, you can always manually check which files the
# preprocessing created.
export TRAIN_DATA_PATH="$data_dir"/my-tiny-c4-gpt2-tok/train
# We simply use the validation set for both evaluation and testing in
# the example. Of course, this is redundant, but makes it easier to
# change the example to include a real test set. Also, we need to
# supply a test set assuming the data argument is given like in the
# example.
export EVAL_DATA_PATH="$TRAIN_DATA_PATH"
export TEST_DATA_PATH="$EVAL_DATA_PATH"

export TOKENIZER_MODEL_FILE="$root_scratch_dir"/"$project_name"/example-data/t5-small-tokenizer/spiece.model

export MODEL_CHECKPOINT_DIR="$checkpoint_dir"

srun env -u CUDA_VISIBLE_DEVICES bash "$(get_curr_dir)"/../container_run.sh \
     bash "$training_script"

pop_curr_file
