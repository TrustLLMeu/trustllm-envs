#!/usr/bin/env bash

# Run a model training on JUWELS Booster.

#SBATCH --nodes=8
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48  # 48 physical cores per node.
#SBATCH --threads-per-core=1  # Use only physical CPU cores.
#SBATCH --gres=gpu:4
#SBATCH --time=23:59:59
#SBATCH --account=trustllm-eu
# Use `develbooster` for debugging, `booster` for "normal" jobs, and
# `largebooster` for jobs on more than 256 nodes.
#SBATCH --partition=booster

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

# Fix Triton cache dir issues; see
# https://github.com/triton-lang/triton/pull/4295. Can remove when
# Triton is updated to a version that includes this fix.
export TRITON_CACHE_DIR="$triton_cache_dir"/cache/"$SLURM_JOB_ID"
mkdir -p "$TRITON_CACHE_DIR"

# Try to reduce link flips.
export NCCL_IB_TIMEOUT=50
export UCX_RC_TIMEOUT=4s
export NCCL_IB_RETRY_CNT=10

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

# We have 48 physical CPU cores on JUWELS Booster nodes, so configure
# 8 + 3 = 11 data workers per GPU in total; this leaves one CPU for
# the main process.
export TRAIN_NUM_WORKERS=8
export EVAL_NUM_WORKERS=3

# model cfg
export TRAIN_CONFIG_YAML_FILE="$(get_curr_dir)"/../conf-yamls/baseline-2.2B.yaml

# data
data_dir=/p/data1/trustllmd/filatov1/data
export INPUT_DATA_ROOT_DIR="$data_dir"/baseline-llm-foundry

# random seed
export GLOBAL_SEED=1012

# tokenizer
export MAX_SEQ_LEN=4096
export TOKENIZER_DIR=/p/data1/trustllmd/baseline_tok

# model
export N_LAYERS=32
export D_MODEL_BASE=4096
export D_MODEL="$D_MODEL_BASE" # baseline: 2048, proxy: 512
export D_HEAD=128 # will keep it fixed across muP models
export EXPANSION_RATIO=3.5

export N_HEADS_BASE="$((D_MODEL_BASE / D_HEAD))"
export N_HEADS="$((D_MODEL / D_HEAD))"
export KV_N_HEADS_BASE=8
export KV_N_HEADS="$((KV_N_HEADS_BASE * D_MODEL / D_MODEL_BASE))"

# optimizer
export OPTIMIZER_NAME=adamw
export BETA_1=0.9
export BETA_2=0.98
export WEIGHT_DECAY=1e-02
export EPS_BASE=1e-15
# base_lrs=( 7.62939453e-06 1.52587891e-05 3.05175781e-05 6.10351562e-05 1.22070312e-04 2.44140625e-04 4.88281250e-04 9.76562500e-04 1.95312500e-03 ) # np.logspace(-17, -9, 9, base=2)
# export LR_BASE="${base_lrs[$SLURM_ARRAY_TASK_ID]}"
export LR_BASE=0.00390625  # 2^-8
export INIT_STD_BASE=0.01

# batching
export MICRO_BS=1
export EVAL_MICRO_BS="$((2 * MICRO_BS))"
export GLOBAL_BS=1024

# parallelisation / performance
export PRECISION="amp_bf16" # amp_bf16 / amp_fp16
export FSDP_STRATEGY="FULL_SHARD"
export FSDP_PRECISION="DEFAULT"  # gradients are fp32

# schedule
export SCHEDULER_NAME="constant_decay_with_warmup"
export T_WARMUP=119209
# 2T token horizon (decay after 476837 steps)
export T_CONSTANT=357628
export T_DECAY=47684
# maximum (5T) token horizon (decay after 1192093 steps)
# export T_CONSTANT=1072884
# export T_DECAY=119209
export ALPHA_C=1.0
export ALPHA_F=0.0
# 2T token horizon (with 10% decay after 476837 steps)
export MAX_DURATION=524521
# maximum (5T) token horizon (with 10% decay after 1192093 steps)
# export MAX_DURATION=1311302
export T_WARMUP="$T_WARMUP"ba
export T_CONSTANT="$T_CONSTANT"ba
export T_DECAY="$T_DECAY"ba
export MAX_DURATION="$MAX_DURATION"ba
# export RESET_TIME=false

# eval / checkpointing intervals
export EVAL_INTERVAL=1600
export SAVE_INTERVAL=1600
export EVAL_INTERVAL="$EVAL_INTERVAL"ba
export SAVE_INTERVAL="$SAVE_INTERVAL"ba
export SAVE_OVERWRITE=false
export SAVE_NUM_CHECKPOINTS_TO_KEEP=-1

# experiment
export EXPERIMENT_NAME=baseline
export RUN_NAME=run_bs-"$GLOBAL_BS"_lr-"$LR_BASE"_dur-"$MAX_DURATION"_96-nodes

# save/load paths
export SAVE_FOLDER="$checkpoint_dir"/"$EXPERIMENT_NAME"/"$RUN_NAME"/checkpoints
# Automatically resume training. To force a restart, set
# `LOAD_PATH=null` unconditionally.
export LOAD_PATH="$SAVE_FOLDER"/latest-rank0.pt
if ! [ -f "$LOAD_PATH" ]; then
    export LOAD_PATH=null
fi
export TENSORBOARD_LOG_DIR="$checkpoint_dir"/"$EXPERIMENT_NAME"/"$RUN_NAME"/tensorboard_logs
export MLFLOW_LOG_DIR="$checkpoint_dir"/mlruns
export MLFLOW_RESUME=false

# Force the baseline training script to be used, for reproducibility.
training_script="$(get_curr_dir)"/../container-scripts/run_baseline_training_container.sh

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
