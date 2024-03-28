#!/usr/bin/env bash

# Preprocess data in parallel on JUWELS Cluster.

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=48
#SBATCH --cpus-per-task=1
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

srun bash -c "
    export WORLD_SIZE=\$SLURM_NTASKS; export RANK=\$SLURM_PROCID;
    ${curr_dir@Q}/../container_run.sh
        bash ${parallel_preprocessing_script@Q}
"

# Probably safer to do this as an interactive run so we don't run into
# time limit problems. May also not be necessary depending on the
# number of files we obtain.
# python "$curr_dir"/../py-scripts/merge_dataset.py --out_root "$OUTPUT_DATA_ROOT"
