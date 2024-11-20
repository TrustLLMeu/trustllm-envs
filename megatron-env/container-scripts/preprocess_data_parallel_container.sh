#!/usr/bin/env bash

# Start a parallel conversion from JSON data to Megatron-LM's binary format.

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

mkdir -p "$(dirname "$OUTPUT_DATA_PREFIX")"

# Below is the Megatron-LM `README.md` GPT data processing example,
# modified to
# - not buffer output,
# - use a local script for parallel processing,
# - use a local dataset,
# - write data to SCRATCH,
# - use a variable number of workers,
# - improve argument ordering sections,
# - make argument passing consistent.
python -u \
    "$(get_curr_dir)"/../py-scripts/preprocess_data_parallel.py \
    --preprocessing-script="$ext_repo_dir"/Megatron-LM/tools/preprocess_data.py \
    --dist-input-files="$INPUT_DATA_FILES" \
    --dist-input-files-glob="$INPUT_DATA_FILES_GLOB" \
    --json-keys=text \
    --output-prefix="$OUTPUT_DATA_PREFIX" \
    --tokenizer-type=GPT2BPETokenizer \
    --vocab-file="$TOKENIZER_VOCAB_FILE" \
    --merge-file="$TOKENIZER_MERGE_FILE" \
    --append-eod \
    --workers="$NUM_WORKERS"

# The same as above, but using a SentencePiece tokenizer.
# python -u \
#     "$(get_curr_dir)"/../py-scripts/preprocess_data_parallel.py \
#     --preprocessing-script="$ext_repo_dir"/Megatron-LM/tools/preprocess_data.py \
#     --dist-input-files="$INPUT_DATA_FILES" \
#     --dist-input-files-glob="$INPUT_DATA_FILES_GLOB" \
#     --json-keys=text \
#     --output-prefix="$OUTPUT_DATA_PREFIX" \
#     --tokenizer-type=SentencePieceTokenizer \
#     --tokenizer-model="$TOKENIZER_MODEL_FILE" \
#     --append-eod \
#     --workers="$NUM_WORKERS"

pop_curr_file
