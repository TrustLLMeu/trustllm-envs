#!/usr/bin/env bash

# Start a training run.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

_activated_container="${_ACTIVATED_CONTAINER:-0}"
if ! ((_activated_container)); then
    echo 'Container has not been activated; please use' \
         "\`bash container_run.sh\` to run container scripts."
    exit 1
fi

# -----

# Set defaults for number of workers if not given.
TRAIN_NUM_WORKERS="${TRAIN_NUM_WORKERS:-0}"
EVAL_NUM_WORKERS="${EVAL_NUM_WORKERS:-0}"

vocab_size="$(python -u "$(get_curr_dir)"/../py-scripts/get_vocab_size.py "$TOKENIZER_DIR")"
echo "Fetched vocab size: $vocab_size"

# Vocab size will be padded to a multiple of this value.
pad_vocab_size_to=128
if [ "$((vocab_size % pad_vocab_size_to))" -eq 0 ]; then
    padded_vocab_size="$vocab_size"
else
    padded_vocab_size="$((vocab_size + pad_vocab_size_to - (vocab_size % pad_vocab_size_to)))"
fi

cd "$ext_repo_dir"/llm-foundry/scripts

# Below is the LLM Foundry README quickstart example, modified to
# - not buffer output,
# - run multi-node,
# - use a variable YAML file,
# - use local preprocessed data from SCRATCH,
# - use a local tokenizer,
# - use the name of the dataset as splits,
# - use multiple CPUs for data processing (variables defined outside
#   script),
# - use FlashAttention-2,
# - use a padded vocab size,
# - save checkpoints to SCRATCH.

# Train a model for 10 batches
python -u -m composer \
    --nproc="$DEVICES_PER_NODE" \
    --world_size="$WORLD_SIZE" \
    --node_rank="$NODE_RANK" \
    --master_addr="$MASTER_ADDR" \
    --master_port="$MASTER_PORT" \
    train/train.py \
    "$TRAIN_CONFIG_YAML_FILE" \
    variables.run_name="$RUN_NAME" \
    variables.global_seed="$GLOBAL_SEED" \
    variables.data_local="$INPUT_DATA_ROOT_DIR" \
    variables.max_seq_len="$MAX_SEQ_LEN" \
    tokenizer.name="$TOKENIZER_DIR" \
    train_loader.num_workers="$TRAIN_NUM_WORKERS" \
    global_train_batch_size="$GLOBAL_BS" \
    device_train_microbatch_size="$MICRO_BS" \
    device_eval_batch_size="$EVAL_MICRO_BS" \
    model.vocab_size="$padded_vocab_size" \
    model.d_model="$D_MODEL" \
    model.n_layers="$N_LAYERS" \
    model.n_heads="$N_HEADS" \
    model.expansion_ratio="$EXPANSION_RATIO" \
    model.attn_config.kv_n_heads="$KV_N_HEADS" \
    model.init_config._init_std_base="$INIT_STD_BASE" \
    model._mup_config.d_model_base="$D_MODEL_BASE" \
    model._mup_config.n_heads_base="$N_HEADS_BASE" \
    precision="$PRECISION" \
    fsdp_config.sharding_strategy="$FSDP_STRATEGY" \
    fsdp_config.mixed_precision="$FSDP_PRECISION" \
    optimizer.name="$OPTIMIZER_NAME" \
    optimizer.lr="$LR_BASE" \
    optimizer.betas=\["$BETA_1","$BETA_2"\] \
    model._mup_config.eps_base="$EPS_BASE" \
    optimizer.weight_decay="$WEIGHT_DECAY" \
    scheduler.name="$SCHEDULER_NAME" \
    scheduler.t_warmup="$T_WARMUP" \
    scheduler.t_constant="$T_CONSTANT" \
    scheduler.t_decay="$T_DECAY" \
    scheduler.alpha_c="$ALPHA_C" \
    scheduler.alpha_f="$ALPHA_F" \
    max_duration="$MAX_DURATION" \
    eval_interval="$EVAL_INTERVAL" \
    save_folder="$SAVE_FOLDER" \
    save_interval="$SAVE_INTERVAL" \
    save_overwrite="$SAVE_OVERWRITE" \
    save_num_checkpoints_to_keep="$SAVE_NUM_CHECKPOINTS_TO_KEEP" \
    loggers.mlflow.experiment_name="$EXPERIMENT_NAME" \
    loggers.mlflow.tracking_uri="$MLFLOW_LOG_DIR" \
    loggers.mlflow.resume="$MLFLOW_RESUME" \
    loggers.tensorboard.log_dir="$TENSORBOARD_LOG_DIR" \
    load_path="$LOAD_PATH"

# # Convert the model to HuggingFace format
# python inference/convert_composer_to_hf.py \
#   --composer_path mpt-125m/ep0-ba10-rank0.pt \
#   --hf_output_path mpt-125m-hf \
#   --output_precision bf16 \
#   # --hf_repo_for_upload user-org/repo-name

# # Evaluate the model on a subset of tasks
# composer eval/eval.py \
#   eval/yamls/hf_eval.yaml \
#   icl_tasks=eval/yamls/copa.yaml \
#   model_name_or_path=mpt-125m-hf

# # Generate responses to prompts
# python inference/hf_generate.py \
#   --name_or_path mpt-125m-hf \
#   --max_new_tokens 256 \
#   --prompts \
#     "The answer to life, the universe, and happiness is" \
#     "Here's a quick recipe for baking chocolate chip cookies: Start by"

pop_curr_file
