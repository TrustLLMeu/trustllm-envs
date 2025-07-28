#!/usr/bin/env bash

# Serve a model for inference.

set -euo pipefail

_activated_container="${_ACTIVATED_CONTAINER:-0}"
if ! ((_activated_container)); then
    echo 'Container has not been activated; please use' \
         "\`bash container_run.sh\` to run container scripts."
    exit 1
fi

# -----

torchtitan_repo_dir="$ext_repo_dir"/torchtitan

# Below is a TorchTitan Llama-2 pretraining example configuration,
# with major settings being
# - use variable config values,
# - run multi-node,
# - run for only 10 steps,
# - use BF16 precision,
# - use smaller micro and global batch sizes,
# - use FSDP2 as the sole parallelization strategy,
# - disable gradient accumulation fusion (required for FSDP2),
# - use a local tokenizer,
# - use local preprocessed data from SCRATCH,
# - use multiple CPUs for data processing (variables defined outside
#   script),
# - save checkpoints to SCRATCH,
# - log to SCRATCH.

export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
python -u -m torchrun_jsc \
       --nproc_per_node=gpu \
       --nnodes="$NUM_NODES" \
       --rdzv_id="$RDZV_ID" \
       --rdzv_endpoint="$MASTER_ADDR":"$MASTER_PORT" \
       --rdzv_backend=c10d \
       "$torchtitan_repo_dir"/torchtitan/tools/server/serve_model.py \
       --dump_folder="$SERVE_FROM_DIR" \
       --new_dump_folder="$DUMP_DIR" \
       --server_address="$MASTER_ADDR" \
       --server_port="$SERVER_PORT"
