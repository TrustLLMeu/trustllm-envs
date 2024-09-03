#!/usr/bin/env bash

# Start a conversion from JSON data to the `streaming` library's
# binary format. `streaming` is LLM Foundry's data library.

set -euo pipefail

_activated_container="${_ACTIVATED_CONTAINER:-0}"
if ! ((_activated_container)); then
    echo 'Container has not been activated; please use' \
         "\`bash container_run.sh\` to run container scripts."
    exit 1
fi

# -----

cd "$ext_repo_dir"/llm-foundry/scripts/data_prep

# Below is the LLM Foundry `scripts/data_prep` README JSON data
# example, modified to
# - not buffer output,
# - use a local dataset,
# - write data to SCRATCH,
# - use a local tokenizer,
# - do not compress the resulting binary file.

# Convert json dataset to StreamingDataset format
python -u convert_dataset_json.py \
  --path "$INPUT_DATA_FILE" \
  --out_root "$OUTPUT_DATA_DIR" --split train \
  --concat_tokens 2048 --tokenizer "$TOKENIZER_DIR" \
  --get_bos_token_id --get_eos_token_id

# Below is the LLM Foundry README quickstart example, modified to
# - be executed from the `scripts/data_prep` directory,
# - write data to SCRATCH,

# # Convert C4 dataset to StreamingDataset format
# python convert_dataset_hf.py \
#   --dataset c4 --data_subset en \
#   --out_root "$data_dir"/my-copy-c4 --splits train_small val_small \
#   --concat_tokens 2048 --tokenizer EleutherAI/gpt-neox-20b --eos_text '<|endoftext|>'
