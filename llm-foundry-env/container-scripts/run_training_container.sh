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
TRAIN_NUM_WORKERS="${TRAIN_NUM_WORKERS:-0}"
EVAL_NUM_WORKERS="${EVAL_NUM_WORKERS:-0}"

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
    data_local="$INPUT_DATA_ROOT_DIR" \
    tokenizer.name="$TOKENIZER_DIR" \
    train_loader.num_workers="$TRAIN_NUM_WORKERS" \
    train_loader.dataset.split=train \
    eval_loader.num_workers="$EVAL_NUM_WORKERS" \
    eval_loader.dataset.split=val \
    model.attn_config.attn_impl=flash \
    max_duration=10ba \
    eval_interval=0 \
    save_folder="$MODEL_CHECKPOINT_DIR"

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
