#!/usr/bin/env bash

# Preprocess data on JUWELS Cluster.

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --hint=nomultithread  # Use only physical CPU cores.
#SBATCH --time 00:20:00
#SBATCH --account=trustllm
# Use `devel` for debugging, `batch` for "normal" jobs, `mem192` for
# nodes with higher memory, and `large` for jobs on more than 256
# nodes.
#SBATCH --partition=devel

set -euo pipefail

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

export INPUT_DATA_FILE=/p/scratch/trustllm/example-data/tiny-c4-100k.jsonl
export TOKENIZER_DIR=/p/scratch/trustllm/example-data/gpt2-tokenizer
export OUTPUT_DATA_ROOT="$data_dir"/my-tiny-c4

srun "$curr_dir"/../container_run.sh \
     bash "$preprocessing_script"
