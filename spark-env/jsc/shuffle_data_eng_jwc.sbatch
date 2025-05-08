#!/usr/bin/env bash

# Preprocess data on JUWELS Cluster.

#SBATCH --nodes=64
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48  # 48 physical cores per node.
#SBATCH --threads-per-core=1  # Use only physical CPU cores.
#SBATCH --time=02:00:00
#SBATCH --account=trustllm-eu
# Use `devel` for debugging, `batch` for "normal" jobs, `mem192` for
# nodes with higher memory, and `large` for jobs on more than 256
# nodes.
#SBATCH --partition=batch
#SBATCH --array=0-63%1

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

# Total CPU memory on the machine.
export AVAILABLE_MEM_GB=96

export MASTER_ADDR="$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)"
if [ "$SYSTEMNAME" = juwelsbooster ] \
       || [ "$SYSTEMNAME" = juwels ] \
       || [ "$SYSTEMNAME" = jurecadc ] \
       || [ "$SYSTEMNAME" = jusuf ]; then
    # Allow communication over InfiniBand cells on JSC machines.
    MASTER_ADDR="$MASTER_ADDR"i
fi
export MASTER_PORT=54123

# Colon-separated list of JSON files to process. Set to empty
# string ('') if not desired.
# export INPUT_DATA_FILES="$root_scratch_dir"/"$project_name"/example-data/tiny-c4-100k.jsonl
num_shards=64;
rank="$SLURM_ARRAY_TASK_ID";
file_list_file="$(get_curr_dir)"/../fineweb-files.txt
find /p/data1/datasets/fineweb/data/ -name '*.parquet' | sort > "$file_list_file"
export INPUT_DATA_FILES="$(awk -v n="$num_shards" -v offset="$rank" '(NR - 1 + n) % n == offset' "$file_list_file" | awk 'BEGIN { RS=""; } { line=$0; gsub(/\n/, ":", line); print line; }')"
echo "INPUT_DATA_FILES: $INPUT_DATA_FILES"
# Glob-expression of JSON files to process. Set to empty string ('')
# if not desired.
# export INPUT_DATA_FILES_GLOB=/p/data1/datasets/fineweb-2/data/swe_Latn/train/'*'.parquet
# export INPUT_DATA_FILES_GLOB=/p/data1/datasets/fineweb/data/CC-MAIN-'*'/'*'.parquet
export INPUT_DATA_FILES_GLOB=''

# export OUTPUT_DATA_DIR="$data_dir"/fineweb-2/swe/train-shuffled_"$SLURM_JOB_NUM_NODES"-nodes
export OUTPUT_DATA_DIR="$data_dir"/fineweb/train-shuffled_shard-"$rank"-of-"$num_shards"_"$SLURM_JOB_NUM_NODES"-nodes
# export OUTPUT_DATA_DIR="$data_dir"/my-tiny-c4-t5-small-tok/val

# Clean up prev. job
echo "before cleanup: $(date --iso-8601=seconds)"
ls -l "$cache_dir"/spark* || srun bash "$(get_curr_dir)"/clean_up_spark.sh "$cache_dir"/spark*
echo "after cleanup: $(date --iso-8601=seconds)"

# We assign to a variable again so Bash can do the quoted
# interpolation.
_curr_dir="$(get_curr_dir)"

srun bash -c "
    export WORLD_SIZE=\"\$((SLURM_JOB_NUM_NODES - 1))\"; \\
    export NODE_RANK=\"\$SLURM_NODEID\"; \\
    bash ${_curr_dir@Q}/../container_run.sh \\
        bash ${_curr_dir@Q}/../container-scripts/shuffle_data_container.sh
"

echo "before cleanup: $(date --iso-8601=seconds)"
srun bash "$(get_curr_dir)"/clean_up_spark.sh "$cache_dir"/spark*
echo "after cleanup: $(date --iso-8601=seconds)"

pop_curr_file
