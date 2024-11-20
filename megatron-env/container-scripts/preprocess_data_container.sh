#!/usr/bin/env bash

# Start a conversion from JSON data to Megatron-LM's binary format.

set -euo pipefail

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
# - write data to SCRATCH,
# - use a variable number of workers,
# - improve argument ordering sections,
# - make argument passing consistent.
python -u \
    "$ext_repo_dir"/Megatron-LM/tools/preprocess_data.py \
    --input="$INPUT_DATA_FILE" \
    --json-keys=text \
    --output-prefix="$OUTPUT_DATA_PREFIX" \
    --tokenizer-type=GPT2BPETokenizer \
    --vocab-file="$TOKENIZER_VOCAB_FILE" \
    --merge-file="$TOKENIZER_MERGE_FILE" \
    --append-eod \
    --workers="$NUM_WORKERS"

# The same as above, but using a SentencePiece tokenizer.
# python -u \
#     "$ext_repo_dir"/Megatron-LM/tools/preprocess_data.py \
#     --input="$INPUT_DATA_FILE" \
#     --json-keys=text \
#     --output-prefix="$OUTPUT_DATA_PREFIX" \
#     --tokenizer-type=SentencePieceTokenizer \
#     --tokenizer-model="$TOKENIZER_MODEL_FILE" \
#     --append-eod \
#     --workers="$NUM_WORKERS"
