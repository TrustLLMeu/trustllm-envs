#!/usr/bin/env bash

# Start a parallel conversion from JSON data to NeMo's binary format.

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

mkdir -p "$(dirname "$OUTPUT_DATA_PREFIX")"

# Below is the NeMo `gpt_training.rst` HuggingFace tokenizer data
# processing example, modified to
# - not buffer output,
# - use a local script for parallel processing,
# - use a local dataset,
# - write data to SCRATCH,
# - use a local tokenizer,
# - use a variable number of workers,
# - improve argument ordering sections,
# - make argument passing consistent.

python -u \
    "$(get_curr_dir)"/../py-scripts/preprocess_data_for_megatron_parallel.py \
    --preprocessing-script="$ext_repo_dir"/NeMo/scripts/nlp_language_modeling/preprocess_data_for_megatron.py \
    --dist-input-files="$INPUT_DATA_FILES" \
    --dist-input-files-glob="$INPUT_DATA_FILES_GLOB" \
    --json-keys=text \
    --dataset-impl=mmap \
    --output-prefix="$OUTPUT_DATA_PREFIX" \
    --tokenizer-library=megatron \
    --tokenizer-type=GPT2BPETokenizer \
    --vocab="$TOKENIZER_VOCAB_FILE" \
    --merge-file="$TOKENIZER_MERGE_FILE" \
    --append-eod \
    --workers="$NUM_WORKERS"

# The same as above, but using a SentencePiece tokenizer.
# python -u \
#     "$(get_curr_dir)"/../py-scripts/preprocess_data_for_megatron_parallel.py \
#     --preprocessing-script="$ext_repo_dir"/NeMo/scripts/nlp_language_modeling/preprocess_data_for_megatron.py \
#     --dist-input-files="$INPUT_DATA_FILES" \
#     --dist-input-files-glob="$INPUT_DATA_FILES_GLOB" \
#     --json-keys=text \
#     --dataset-impl=mmap \
#     --output-prefix="$OUTPUT_DATA_PREFIX" \
#     --tokenizer-library=sentencepiece \
#     --tokenizer-model="$TOKENIZER_MODEL_FILE" \
#     --append-eod \
#     --workers="$NUM_WORKERS"

pop_curr_file
