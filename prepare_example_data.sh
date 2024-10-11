#!/usr/bin/env bash

# Prepare example data. Run from inside container.

set -euo pipefail

_activated_container="${_ACTIVATED_CONTAINER:-0}"
if ! ((_activated_container)); then
    echo 'Container has not been activated; please use' \
         "\`bash container_run.sh\` to run container scripts."
    exit 1
fi

if [ -z "$1" ]; then
    echo 'Please pass the directory to put example data into' \
         'as the first argument.'
    exit 1
fi

data_dir="$1"  # e.g., `/p/scratch/trustllm-eu/example-data`

mkdir -p "$data_dir"

# First, prepare example text data by taking the first 100k samples
# from C4 train and the first 10k samples from C4 validation.

wget -O - \
     https://huggingface.co/datasets/allenai/c4/resolve/main/en/c4-train.00000-of-01024.json.gz \
     > "$data_dir"/c4-train.00000-of-01024.json.gz
wget -O - \
     https://huggingface.co/datasets/allenai/c4/resolve/main/en/c4-validation.00000-of-00008.json.gz \
     > "$data_dir"/c4-validation.00000-of-00008.json.gz

gunzip "$data_dir"/c4-train.00000-of-01024.json.gz
gunzip "$data_dir"/c4-validation.00000-of-00008.json.gz

# We try to give a more indicative file ending by renaming here
# (`json` → `jsonl`).
mv "$data_dir"/c4-train.00000-of-01024.json "$data_dir"/c4-train.00000-of-01024.jsonl
mv "$data_dir"/c4-validation.00000-of-00008.json "$data_dir"/c4-validation.00000-of-00008.jsonl

head -n 100000 "$data_dir"/c4-train.00000-of-01024.jsonl \
     > "$data_dir"/tiny-c4-100k.jsonl
head -n 10000 "$data_dir"/c4-validation.00000-of-00008.jsonl \
     > "$data_dir"/tiny-c4-10k.jsonl

# Now, download two example tokenizers to be able to show off how to
# use both HuggingFace and SentencePiece tokenizers.

env TOK_SAVE_DIR="$data_dir"/gpt2-tokenizer \
    HF_HUB_OFFLINE=0 \
    TRANSFORMERS_OFFLINE=0 \
    python -c 'import os; from transformers import AutoTokenizer; tok = AutoTokenizer.from_pretrained("gpt2"); tok.save_pretrained(os.environ["TOK_SAVE_DIR"])'
env TOK_SAVE_DIR="$data_dir"/t5-small-tokenizer \
    HF_HUB_OFFLINE=0 \
    TRANSFORMERS_OFFLINE=0 \
    python -c 'import os; from transformers import AutoTokenizer; tok = AutoTokenizer.from_pretrained("t5-small"); tok.save_pretrained(os.environ["TOK_SAVE_DIR"])'
