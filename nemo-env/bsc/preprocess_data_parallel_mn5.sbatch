#!/usr/bin/env bash

# Preprocess data in parallel on MareNostrum 5.

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=64  # 64 physical cores per node.
#SBATCH --hint=nomultithread  # Use only physical CPU cores.
#SBATCH --gres=gpu:0  # 4 GPUs per node
#SBATCH --time=00:20:00
#SBATCH --account=ehpc09
# Use `acc_debug` for debugging, `acc_ehpc` for "normal" jobs.
#SBATCH --qos=acc_debug

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

export NUM_WORKERS="$SRUN_CPUS_PER_TASK"

# Colon-separated list of JSON files to process. Set to empty
# string ('') if not desired.
export INPUT_DATA_FILES="$root_scratch_dir"/"$project_name"/example-data/tiny-c4-100k.jsonl
# Glob-expression of JSON files to process. Set to empty string ('')
# if not desired.
export INPUT_DATA_FILES_GLOB=''

export TOKENIZER_VOCAB_FILE="$root_scratch_dir"/"$project_name"/example-data/gpt2-tokenizer/vocab.json
export TOKENIZER_MERGE_FILE="$root_scratch_dir"/"$project_name"/example-data/gpt2-tokenizer/merges.txt
# The SentencePiece tokenizer is not used by default in the example,
# but we include and export it here just so it's available when
# desired.
export TOKENIZER_MODEL_FILE="$root_scratch_dir"/"$project_name"/example-data/t5-small-tokenizer/spiece.model

# For simplicity, the final data files this script will generate will
# always end with "_text_document", even if it does not match given
# the arguments.
export OUTPUT_DATA_PREFIX="$data_dir"/my-tiny-c4-gpt2-tok/train
# export OUTPUT_DATA_PREFIX="$data_dir"/my-tiny-c4-t5-small-tok/train

# We assign to a variable again so Bash can do the quoted
# interpolation.
_curr_dir="$(get_curr_dir)"

srun bash -c "
    export WORLD_SIZE=\"\$SLURM_NTASKS\"; export RANK=\"\$SLURM_PROCID\"; \\
    bash ${_curr_dir@Q}/../container_run.sh \\
        bash ${parallel_preprocessing_script@Q}
"

# Probably safer to do this as an interactive run so we don't run into
# time limit problems, since it is a destructive operation. However,
# for convenience, this is included here for now.
bash "$(get_curr_dir)"/../container_run.sh \
     python -u "$(get_curr_dir)"/../py-scripts/merge_datasets.py \
         --input="$OUTPUT_DATA_PREFIX" \
         --output-prefix="$OUTPUT_DATA_PREFIX"_text_document

pop_curr_file
