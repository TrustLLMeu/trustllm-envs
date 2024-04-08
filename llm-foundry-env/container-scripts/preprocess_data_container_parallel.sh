#!/usr/bin/env bash

# Start a parallel conversion from JSON data to the `streaming`
# library's binary format. `streaming` is llm-foundry's data library.

set -euo pipefail

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

# Make sure the repo script files can be imported (could also adjust
# `PYTHONPATH` but this way it's more similar to the non-parallel
# script).
cd "$ext_repo_dir"/llm-foundry/scripts/data_prep

# Below is the llm-foundry `scripts/data_prep` README JSON data
# example, modified to
# - not buffer output,
# - use a local script for parallel processing,
# - use an example tiny C4 dataset,
# - write data to scratch,
# - use a local tokenizer,
# - do not compress the resulting binary file.

# Convert json dataset to StreamingDataset format
# Alternatively, you can use
# `"$(get_curr_dir)"/../py-scripts/convert_dataset_json_parallel_patching.py`
# for a version that should benefit from small-scale changes to the
# underlying llm-foundry code.
python -u "$(get_curr_dir)"/../py-scripts/convert_dataset_json_parallel.py \
  --path "$INPUT_DATA_FILE" \
  --out_root "$OUTPUT_DATA_DIR" --split train \
  --concat_tokens 2048 --tokenizer "$TOKENIZER_DIR" --eos_text '<|endoftext|>'

pop_curr_file
