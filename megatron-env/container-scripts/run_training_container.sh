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

# Set defaults for number of workers if not given.
PER_SPLIT_NUM_WORKERS="${PER_SPLIT_NUM_WORKERS:-0}"

megatron_repo_dir="$ext_repo_dir"/Megatron-LM

# Below is a Megatron-LM Llama-2 pretraining example configuration,
# with major settings being
# - use variable config values,
# - run multi-node,
# - run for only 10 steps,
# - no evaluation,
# - use BF16 precision,
# - use smaller micro and global batch sizes,
# - use FSDP2 as the sole parallelization strategy,
# - disable gradient accumulation fusion (required for FSDP2),
# - use PyTorch DCP checkpoint format (also required for FSDP2),
# - do not tie embedding layers (also required for FSDP2),
# - pass "no async allreduce" argument even though it's ignored to
#   avoid an error,
# - use a local tokenizer,
# - use local preprocessed data from SCRATCH,
# - use multiple CPUs for data processing (variables defined outside
#   script),
# - save checkpoints to SCRATCH,
# - log to SCRATCH.

seq_length=4096
env NVTE_APPLY_QK_LAYER_SCALING=1 python -u -m torchrun_jsc \
       --nproc_per_node=gpu \
       --nnodes="$NUM_NODES" \
       --rdzv_id="$RDZV_ID" \
       --rdzv_endpoint="$MASTER_ADDR":"$MASTER_PORT" \
       --rdzv_backend=c10d \
       "$megatron_repo_dir"/pretrain_gpt.py  \
       --train-iters=10 \
       --log-interval=1 \
       --eval-iters=0 \
       --eval-interval=10 \
       --bf16 \
       --accumulate-allreduce-grads-in-fp32 \
       --micro-batch-size=1 \
       --global-batch-size=8 \
       --use-torch-fsdp2 \
       --no-gradient-accumulation-fusion \
       --ckpt-format torch_dist \
       --async-save \
       --untie-embeddings-and-output-weights \
       --no-async-tensor-model-parallel-allreduce \
       --tensor-model-parallel-size=1 \
       --pipeline-model-parallel-size=1 \
       --num-layers=32 \
       --hidden-size=4096 \
       --ffn-hidden-size=11008 \
       --num-attention-heads=32 \
       --num-query-groups=1 \
       --seq-length="$seq_length" \
       --max-position-embeddings="$seq_length" \
       --position-embedding-type=rope \
       --normalization=RMSNorm \
       --norm-epsilon=1e-5 \
       --swiglu \
       --disable-bias-linear \
       --attention-dropout=0.0 \
       --hidden-dropout=0.0 \
       --init-method-std=0.02 \
       --apply-query-key-layer-scaling \
       --optimizer=adam \
       --weight-decay=0.01 \
       --clip-grad=1.0 \
       --lr=2e-4 \
       --lr-decay-style=cosine \
       --lr-warmup-iters=500 \
       --lr-warmup-init=0.0 \
       --lr-decay-iters=49500 \
       --min-lr=0.0 \
       --adam-beta1=0.9 \
       --adam-beta2=0.98 \
       --adam-eps=1e-8 \
       --tokenizer-type=GPT2BPETokenizer \
       --vocab-file="$TOKENIZER_VOCAB_FILE" \
       --merge-file="$TOKENIZER_MERGE_FILE" \
       --dataloader-type=cyclic \
       --train-data-path 1.0 "$TRAIN_DATA_PREFIX" \
       --valid-data-path 1.0 "$EVAL_DATA_PREFIX" \
       --test-data-path 1.0 "$TEST_DATA_PREFIX" \
       --data-cache-path="$cache_dir"/data-caches \
       --num-workers="$PER_SPLIT_NUM_WORKERS" \
       --load="$MODEL_CHECKPOINT_DIR"/checkpoints \
       --save="$MODEL_CHECKPOINT_DIR"/checkpoints \
       --save-interval=1000 \
       --tensorboard-dir="$MODEL_CHECKPOINT_DIR"/tensorboard_logs \
       --log-params-norm \
       --log-throughput \
       --log-timers-to-tensorboard \
       --log-validation-ppl-to-tensorboard \
       --log-memory-to-tensorboard \
       --save-interval=1234

# Same as above, but using SentencePiece tokenizer.
# python -u -m torchrun_jsc \
#        --nproc_per_node=gpu \
#        --nnodes="$NUM_NODES" \
#        --rdzv_id="$RDZV_ID" \
#        --rdzv_endpoint="$MASTER_ADDR":"$MASTER_PORT" \
#        --rdzv_backend=c10d \
#        "$megatron_repo_dir"/pretrain_gpt.py  \
#        --config-path="$TRAIN_CONFIG_YAML_DIR" \
#        --config-name="$TRAIN_CONFIG_YAML_NAME" \
#        --train-iters=10 \
#        --log-interval=1 \
#        --eval-iters=TODO \
#        --eval-interval=10 \
#        --bf16 \
#        --accumulate-allreduce-grads-in-fp32 \
#        --micro-batch-size=1 \
#        --global-batch-size=8 \
#        --use-torch-fsdp2 \
#        --no-gradient-accumulation-fusion \
#        --ckpt-format torch_dist \
#        --async-save \
#        --untie-embeddings-and-output-weights \
#        --tensor-model-parallel-size=1 \
#        --pipeline-model-parallel-size=1 \
#        --num-layers=32 \
#        --hidden-size=4096 \
#        --ffn-hidden-size=11008 \
#        --num-attention-heads=32 \
#        --num-query-groups=1 \
#        --seq-length="$seq_length" \
#        --max-position-embeddings="$seq_length" \
#        --position-embedding-type=rope \
#        --normalization=RMSNorm \
#        --norm-epsilon=1e-5 \
#        --swiglu \
#        --disable-bias-linear \
#        --attention-dropout=0.0 \
#        --hidden-dropout=0.0 \
#        --init-method-std=0.02 \
#        --apply-query-key-layer-scaling \
#        --optimizer=adam \
#        --weight-decay=0.01 \
#        --clip-grad=1.0 \
#        --lr=2e-4 \
#        --lr-decay-style=cosine \
#        --lr-warmup-iters=500 \
#        --lr-warmup-init=0.0 \
#        --lr-decay-iters=50000 \
#        --min-lr=0.0 \
#        --adam-beta1=0.9 \
#        --adam-beta2=0.98 \
#        --adam-eps=1e-8 \
#        --tokenizer-type=SentencePieceTokenizer \
#        --tokenizer-model="$TOKENIZER_MODEL_FILE" \
#        --dataloader-type=cyclic \
#        --train-data-path=1.0 "$TRAIN_DATA_PREFIX" \
#        --valid-data-path=1.0 "$EVAL_DATA_PREFIX" \
#        --test-data-path=1.0 "$TEST_DATA_PREFIX" \
#        --data-cache-path="$cache_dir"/data-caches \
#        --num-workers="$PER_SPLIT_NUM_WORKERS" \
#        --load="$MODEL_CHECKPOINT_DIR"/checkpoints \
#        --save="$MODEL_CHECKPOINT_DIR"/checkpoints \
#        --save-interval=1000 \
#        --tensorboard-dir="$MODEL_CHECKPOINT_DIR"/tensorboard_logs \
#        --log-params-norm \
#        --log-throughput \
#        --log-timers-to-tensorboard \
#        --log-validation-ppl-to-tensorboard \
#        --log-memory-to-tensorboard \
#        --save-interval=1234
