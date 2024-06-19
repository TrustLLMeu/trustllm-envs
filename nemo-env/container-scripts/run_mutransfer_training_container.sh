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

DO_COORD_CHECK="${DO_COORD_CHECK:-0}"

num_layers=32
num_heads=32
mcore_value=True
te_value=True
make_mup_value=True
num_query_groups=4

exp_name="megatron_llama_mutransfer_my-tiny-c4-gpt2-tok_lr-\${model.optim.lr}__mcore-\${model.mcore_gpt}_te-\${model.transformer_engine}"

python -u \
    "$nemo_repo_dir"/examples/nlp/language_modeling/megatron_gpt_cal_shape.py  \
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
    model.global_batch_size="$((DEVICES_PER_NODE * NUM_NODES))" \
    model.mcore_gpt="$mcore_value" \
    model.transformer_engine="$te_value" \
    +model.fsdp=True \
    +model.fsdp_sharding_strategy=full \
    +model.fsdp_use_orig_params=True \
    +model.fsdp_grad_reduce_dtype=32 \
    +model.fsdp_sharded_checkpoint=True \
    +model.fsdp_cpu_offload=False \
    model.tensor_model_parallel_size=1 \
    model.pipeline_model_parallel_size=1 \
    +model.context_parallel_size=1 \
    model.sequence_parallel=False \
    +model.use_flash_attention=True \
    model.num_layers="$num_layers" \
    model.num_attention_heads="$num_heads" \
    model.num_query_groups="$num_query_groups" \
    model.tokenizer.library=megatron \
    model.tokenizer.type=GPT2BPETokenizer \
    model.tokenizer.model=null \
    model.tokenizer.vocab_file="$TOKENIZER_VOCAB_FILE" \
    model.tokenizer.merge_file="$TOKENIZER_MERGE_FILE" \
    +model.data.data_prefix=\{train:\[1.0,"$TRAIN_DATA_PREFIX"\],validation:\[1.0,"$EVAL_DATA_PREFIX"\],test:\[1.0,"$TEST_DATA_PREFIX"\]\} \
    +model.data.index_mapping_dir="$cache_dir/data-indices" \
    model.data.num_workers="$PER_SPLIT_NUM_WORKERS" \
    model.make_mup="$make_mup_value" \
    model.shape_file="$SHAPE_YAML_FILE" \
    exp_manager.name="$exp_name" \
    exp_manager.exp_dir="$MODEL_CHECKPOINT_DIR"

if ((DO_COORD_CHECK)); then
    python -u \
        "$nemo_repo_dir"/examples/nlp/language_modeling/megatron_gpt_coord_check.py  \
        --config-path="$TRAIN_CONFIG_YAML_DIR" \
        --config-name="$TRAIN_CONFIG_YAML_NAME" \
        trainer.devices="$DEVICES_PER_NODE" \
        trainer.num_nodes="$NUM_NODES" \
        trainer.max_steps=20 \
        trainer.log_every_n_steps=1 \
        trainer.val_check_interval=10 \
        +trainer.num_sanity_val_steps=0 \
        trainer.precision=bf16-mixed \
        model.micro_batch_size=1 \
        model.global_batch_size=8 \
        model.mcore_gpt="$mcore_value" \
        model.transformer_engine="$te_value" \
        +model.fsdp=True \
        +model.fsdp_sharding_strategy=full \
        +model.fsdp_use_orig_params=True \
        +model.fsdp_grad_reduce_dtype=32 \
        +model.fsdp_sharded_checkpoint=True \
        +model.fsdp_cpu_offload=False \
        model.tensor_model_parallel_size=1 \
        model.pipeline_model_parallel_size=1 \
        +model.context_parallel_size=1 \
        model.sequence_parallel=False \
        +model.use_flash_attention=True \
        model.num_layers="$num_layers" \
        model.num_attention_heads="$num_heads" \
        model.num_query_groups="$num_query_groups" \
        model.tokenizer.library=megatron \
        model.tokenizer.type=GPT2BPETokenizer \
        model.tokenizer.model=null \
        model.tokenizer.vocab_file="$TOKENIZER_VOCAB_FILE" \
        model.tokenizer.merge_file="$TOKENIZER_MERGE_FILE" \
        +model.data.data_prefix=\{train:\[1.0,"$TRAIN_DATA_PREFIX"\],validation:\[1.0,"$EVAL_DATA_PREFIX"\],test:\[1.0,"$TEST_DATA_PREFIX"\]\} \
        +model.data.index_mapping_dir="$cache_dir/data-indices" \
        model.data.num_workers="$PER_SPLIT_NUM_WORKERS" \
        model.optim.lr=1e-3 \
        model.make_mup="$make_mup_value" \
        model.shape_file="$SHAPE_YAML_FILE" \
        exp_manager.name="$exp_name" \
        exp_manager.exp_dir="$MODEL_CHECKPOINT_DIR"

else
    python -u \
        "$nemo_repo_dir"/examples/nlp/language_modeling/megatron_gpt_pretraining.py  \
        --config-path="$TRAIN_CONFIG_YAML_DIR" \
        --config-name="$TRAIN_CONFIG_YAML_NAME" \
        trainer.devices="$DEVICES_PER_NODE" \
        trainer.num_nodes="$NUM_NODES" \
        trainer.max_steps=6000 \
        trainer.log_every_n_steps=1 \
        trainer.val_check_interval=500 \
        +trainer.num_sanity_val_steps=0 \
        trainer.precision=bf16-mixed \
        model.micro_batch_size=8 \
        model.global_batch_size=128 \
        model.mcore_gpt="$mcore_value" \
        model.transformer_engine="$te_value" \
        +model.fsdp=True \
        +model.fsdp_sharding_strategy=full \
        +model.fsdp_use_orig_params=True \
        +model.fsdp_grad_reduce_dtype=32 \
        +model.fsdp_sharded_checkpoint=True \
        +model.fsdp_cpu_offload=False \
        model.tensor_model_parallel_size=1 \
        model.pipeline_model_parallel_size=1 \
        +model.context_parallel_size=1 \
        model.sequence_parallel=False \
        +model.use_flash_attention=True \
        model.num_layers="$num_layers" \
        model.hidden_size=256 \
        model.ffn_hidden_size=688 \
        model.num_attention_heads="$num_heads" \
        model.num_query_groups="$num_query_groups" \
        model.tokenizer.library=megatron \
        model.tokenizer.type=GPT2BPETokenizer \
        model.tokenizer.model=null \
        model.tokenizer.vocab_file="$TOKENIZER_VOCAB_FILE" \
        model.tokenizer.merge_file="$TOKENIZER_MERGE_FILE" \
        +model.data.data_prefix=\{train:\[1.0,"$TRAIN_DATA_PREFIX"\],validation:\[1.0,"$EVAL_DATA_PREFIX"\],test:\[1.0,"$TEST_DATA_PREFIX"\]\} \
        +model.data.index_mapping_dir="$cache_dir/data-indices" \
        model.data.num_workers="$PER_SPLIT_NUM_WORKERS" \
        model.optim.lr=8e-4 \
        model.optim.sched.min_lr=0.0 \
        model.optim.sched.constant_steps=3000 \
        model.make_mup="$make_mup_value" \
        model.shape_file="$SHAPE_YAML_FILE" \
        exp_manager.name="$exp_name" \
        exp_manager.exp_dir="$MODEL_CHECKPOINT_DIR"
fi

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
#     model.mcore_gpt="$mcore_value" \
#     model.transformer_engine="$te_value" \
#     +model.fsdp=True \
#     +model.fsdp_sharding_strategy=full \
#     +model.fsdp_use_orig_params=True \
#     +model.fsdp_grad_reduce_dtype=32 \
#     +model.fsdp_sharded_checkpoint=True \
#     +model.fsdp_cpu_offload=False \
#     model.tensor_model_parallel_size=1 \
#     model.pipeline_model_parallel_size=1 \
#     +model.context_parallel_size=1 \
#     model.sequence_parallel=False \
#     +model.use_flash_attention=True \
#     model.num_layers="$num_layers" \
#     model.num_attention_heads="$num_heads" \
#     model.num_query_groups="$num_query_groups" \
#     model.tokenizer.library=sentencepiece \
#     model.tokenizer.model="$TOKENIZER_MODEL_FILE" \
#     +model.data.data_prefix=\{train:\[1.0,"$TRAIN_DATA_PREFIX"\],validation:\[1.0,"$EVAL_DATA_PREFIX"\]\} \
#     +model.data.index_mapping_dir="$cache_dir/data-indices" \
#     model.data.num_workers="$PER_SPLIT_NUM_WORKERS" \
#     model.make_mup="$make_mup_value" \
#     model.shape_file="$SHAPE_YAML_FILE" \
#     exp_manager.name="$exp_name" \
#     exp_manager.exp_dir="$MODEL_CHECKPOINT_DIR"
