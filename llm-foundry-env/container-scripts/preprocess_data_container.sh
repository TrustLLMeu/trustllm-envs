#!/usr/bin/env bash

# Start a conversion from JSON data to the `streaming` library's
# binary format. `streaming` is llm-foundry's data library.

set -euo pipefail

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"
source "$curr_dir"/../outside-container-scripts/activate_container.sh

# -----

cd "$repo_dir"/llm-foundry/scripts/data_prep

# Below is the llm-foundry `scripts/data_prep` README JSON data
# example, modified to
# - use an example tiny C4 dataset,
# - write data to scratch,
# - use a local tokenizer,
# - do not compress the resulting binary file.

# Convert json dataset to StreamingDataset format
python convert_dataset_json.py \
  --path "$INPUT_DATA_PATH" \
  --out_root "$OUTPUT_DATA_ROOT" --split train \
  --concat_tokens 2048 --tokenizer "$TOKENIZER_DIR" --eos_text '<|endoftext|>'

# Below is the llm-foundry README quickstart example, modified to
# - be executed from the `scripts/data_prep` directory,
# - write data to SCRATCH,
# - use a local tokenizer.

# # Convert C4 dataset to StreamingDataset format
# python convert_dataset_hf.py \
#   --dataset c4 --data_subset en \
#   --out_root "$data_dir"/my-copy-c4 --splits train_small val_small \
#   --concat_tokens 2048 --tokenizer "$TOKENIZER_DIR" --eos_text '<|endoftext|>'
