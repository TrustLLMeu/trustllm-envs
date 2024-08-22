#!/usr/bin/env bash

# Run a model training on JURECA DC.

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128  # 128 physical cores per node.
#SBATCH --threads-per-core=1  # Use only physical CPU cores.
#SBATCH --gres=gpu:4
#SBATCH --time=00:20:00
#SBATCH --account=trustllm-eu
# Use `dc-gpu-devel` for debugging, `dc-gpu` for "normal" jobs, and
# `dc-gpu-large` for jobs on more than 256 nodes.
#SBATCH --partition=dc-gpu-devel

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

export DEVICES_PER_NODE=4

# We have 128 physical CPU cores on JUWELS Booster nodes, so configure
# 17 + 14 = 31 data workers per GPU in total; this leaves one CPU for
# the main process.
export TRAIN_NUM_WORKERS=17
export EVAL_NUM_WORKERS=14

export TRAIN_CONFIG_YAML_FILE=train/yamls/pretrain/mpt-125m.yaml
export INPUT_DATA_ROOT_DIR="$data_dir"/my-tiny-c4-gpt2-tok
export TOKENIZER_DIR="$root_scratch_dir"/"$project_name"/example-data/gpt2-tokenizer
export MODEL_CHECKPOINT_DIR="$checkpoint_dir"/mpt-125m

# We assign to a variable again so Bash can do the quoted
# interpolation.
_curr_dir="$(get_curr_dir)"

srun bash -c "
    export WORLD_SIZE=\"\$((SLURM_JOB_NUM_NODES * DEVICES_PER_NODE))\"; \\
    export NODE_RANK=\"\$SLURM_NODEID\"; \\
    bash ${_curr_dir@Q}/../container_run.sh \\
        bash ${training_script@Q}
"

pop_curr_file
