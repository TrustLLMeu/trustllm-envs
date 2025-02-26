#!/usr/bin/env bash

# Start a training run.

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
       "$torchtitan_repo_dir"/train.py  \
       --job.description='Llama2 7B training' \
       --job.config_file="$torchtitan_repo_dir"/torchtitan/models/llama/train_configs/llama3_8b.toml \
       --job.dump_folder="$checkpoint_dir" \
       --job.print_args \
       --training.steps=10 \
       --training.seq_len=4096 \
       --training.batch_size=1 \
       --training.global_batch_size=8 \
       --training.data_parallel_replicate_degree="$(((NUM_NODES * DEVICES_PER_NODE) / GPUS_PER_REPLICA))" \
       --training.tensor_parallel_degree=1 \
       --training.mixed_precision_param=bfloat16 \
       --training.mixed_precision_reduce=float32 \
       --training.max_norm=1.0 \
       --training.warmup_steps=500 \
       --training.compile \
       --training.dataset=simple_custom \
       --training.dataset_path="$TRAIN_DATA_PATH" \
       --training.dataset_files="$TRAIN_DATA_FILES" \
       --training.dataset_inner_name="$TRAIN_DATA_INNER_NAME" \
       --training.dataset_streaming \
       --training.seed=0 \
       --model.name=llama2 \
       --model.flavor=7B \
       --model.norm_type=rmsnorm \
       --model.tokenizer_path="$TOKENIZER_MODEL_FILE" \
       --activation_checkpoint.mode=selective \
       --activation_checkpoint.selective_ac_option=op \
       --optimizer.name=AdamW \
       --optimizer.lr=3e-4 \
       --optimizer.fused \
       --metrics.log_freq=1 \
       --metrics.enable_tensorboard \
       --checkpoint.enable_checkpoint \
       --checkpoint.interval=1000 \
       --checkpoint.export_dtype=bfloat16 \
       --checkpoint.async_mode=async
