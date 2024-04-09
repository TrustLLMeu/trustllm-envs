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

nemo_repo_dir="$ext_repo_dir"/NeMo

# Below uses the NeMo Llama-2 pretraining example configuration,
# with major modifications being
# - use variable config values,
# - run multi-node,
# - run for only 10 steps,
# - use BF16 precision,
# - use smaller micro and global batch sizes,
# - use FSDP as the sole parallelization strategy,
# - use FlashAttention-2 (unless `model.mcore_gpt=True`),
# - use a local tokenizer,
# - use local preprocessed data from SCRATCH,
# - use multiple CPUs for data processing (variables defined outside
#   script),
# - save checkpoints to SCRATCH.

python -u \
    "$nemo_repo_dir"/examples/nlp/language_modeling/megatron_gpt_pretraining.py  \
    --config-path="$TRAIN_CONFIG_YAML_DIR" \
    --config-name="$TRAIN_CONFIG_YAML_NAME" \
    trainer.devices="$DEVICES_PER_NODE" \
    trainer.num_nodes="$NUM_NODES" \
    trainer.max_steps=10 \
    trainer.log_every_n_steps=1 \
    trainer.val_check_interval=10 \
    +trainer.num_sanity_val_steps=0 \
    trainer.precision=bf16-mixed \
    model.micro_batch_size=1 \
    model.global_batch_size=8 \
    model.mcore_gpt=False \
    +model.fsdp=True \
    +model.fsdp_sharding_strategy=full \
    +model.fsdp_grad_reduce_dtype=32 \
    +model.fsdp_sharded_checkpoint=True \
    model.tensor_model_parallel_size=1 \
    model.pipeline_model_parallel_size=1 \
    model.sequence_parallel=False \
    +model.use_flash_attention=True \
    model.tokenizer.library=megatron \
    model.tokenizer.type=GPT2BPETokenizer \
    model.tokenizer.model=null \
    model.tokenizer.vocab_file="$TOKENIZER_VOCAB_FILE" \
    model.tokenizer.merge_file="$TOKENIZER_MERGE_FILE" \
    +model.data.data_prefix=\{train:\[1.0,"$TRAIN_DATA_PREFIX"\],validation:\[1.0,"$EVAL_DATA_PREFIX"\],test:\[1.0,"$TEST_DATA_PREFIX"\]\} \
    model.data.num_workers="$PER_SPLIT_NUM_WORKERS" \
    exp_manager.exp_dir="$MODEL_CHECKPOINT_DIR"

# Same as above, but using SentencePiece tokenizer.
# python -u \
#     "$nemo_repo_dir"/examples/nlp/language_modeling/megatron_gpt_pretraining.py  \
#     --config-path="$TRAIN_CONFIG_YAML_DIR" \
#     --config-name="$TRAIN_CONFIG_YAML_NAME" \
#     trainer.devices="$DEVICES_PER_NODE" \
#     trainer.num_nodes="$NUM_NODES" \
#     trainer.max_steps=10 \
#     trainer.log_every_n_steps=1 \
#     trainer.val_check_interval=10 \
#     +trainer.num_sanity_val_steps=0 \
#     trainer.precision=bf16-mixed \
#     model.micro_batch_size=1 \
#     model.global_batch_size=8 \
#     model.mcore_gpt=False \
#     +model.fsdp=True \
#     +model.fsdp_sharding_strategy=full \
#     +model.fsdp_grad_reduce_dtype=32 \
#     +model.fsdp_sharded_checkpoint=True \
#     model.tensor_model_parallel_size=1 \
#     model.pipeline_model_parallel_size=1 \
#     model.sequence_parallel=False \
#     +model.use_flash_attention=True \
#     model.tokenizer.library=sentencepiece \
#     model.tokenizer.model="$TOKENIZER_MODEL_FILE" \
#     +model.data.data_prefix=\{train:\[1.0,"$TRAIN_DATA_PREFIX"\],validation:\[1.0,"$EVAL_DATA_PREFIX"\]\} \
#     model.data.num_workers="$PER_SPLIT_NUM_WORKERS" \
#     exp_manager.exp_dir="$MODEL_CHECKPOINT_DIR"
