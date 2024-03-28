#!/usr/bin/env bash

# Start a parallel conversion from JSON data to the `streaming`
# library's binary format. `streaming` is llm-foundry's data library.

set -euo pipefail

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"
source "$curr_dir"/../container-scripts/activate_container.sh

# -----

# Make sure the repo script files can be imported (could also adjust
# `PYTHONPATH` but this way it's more similar to the non-parallel
# script).
cd "$repo_dir"/llm-foundry/scripts/data_prep

# Below is the llm-foundry `scripts/data_prep` README JSON data
# example, modified to
# - use a local script for parallel processing,
# - use an example tiny C4 dataset,
# - write data to scratch,
# - use a local tokenizer,
# - do not compress the resulting binary file.

# Convert json dataset to StreamingDataset format
# Alternatively, you can use
# `"$curr_dir"/../py-scripts/convert_dataset_json_parallel_patching.py`
# for a version that should benefit from small-scale changes to the
# underlying llm-foundry code.
python "$curr_dir"/../py-scripts/convert_dataset_json_parallel.py \
  --path "$INPUT_DATA_PATH" \
  --out_root "$OUTPUT_DATA_ROOT" --split train \
  --concat_tokens 2048 --tokenizer "$TOKENIZER_DIR" --eos_text '<|endoftext|>'
