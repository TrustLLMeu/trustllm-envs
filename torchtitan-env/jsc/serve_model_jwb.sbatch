#!/usr/bin/env bash

# Host a model inference server on JUWELS Booster.

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

export GPUS_PER_REPLICA="$DEVICES_PER_NODE"

export NUM_NODES="$SLURM_JOB_NUM_NODES"
export RDZV_ID="$SLURM_JOB_ID"

export MODEL_CHECKPOINT_DIR="$checkpoint_dir"

export SERVER_PORT=54125

srun env -u CUDA_VISIBLE_DEVICES bash "$(get_curr_dir)"/../container_run.sh \
     bash "$(get_curr_dir)"/../container-scripts/serve_model_container.sh &

bash "$(get_curr_dir)"/../container_run.sh \
     python "$(get_curr_dir)"/../py-scripts/wait_for_server.py \
     --server_address=http://"$MASTER_ADDR" \
     --server_port="$SERVER_PORT"

bash "$(get_curr_dir)"/../container_run.sh \
     python \
     "$torchtitan_repo_dir"/torchtitan/tools/server/send_debug_requests.py \
     --seed=0 \
     --server_address="$MASTER_ADDR" \
     --server_port="$SERVER_PORT"

pop_curr_file
