#!/usr/bin/env bash

# Preprocess data on JUSUF.

#SBATCH --nodes=32
# SBATCH --nodes=4
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128  # 128 physical cores per node.
#SBATCH --threads-per-core=1  # Use only physical CPU cores.
#SBATCH --time=02:00:00
#SBATCH --account=trustllm-eu
# Use `batch` for debugging and "normal" jobs.
#SBATCH --partition=batch
#SBATCH --array=0-0%1

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="$(scontrol show job "$SLURM_JOB_ID" | grep '^[[:space:]]*Command=' | head -n 1 | cut -d '=' -f 2-)"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../configuration.sh

export SRUN_CPUS_PER_TASK="$SLURM_CPUS_PER_TASK"

# Total CPU memory on the machine.
export AVAILABLE_MEM_GB="${AVAILABLE_MEM_GB:-256}"

export MASTER_ADDR="$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)"
if [ "$SYSTEMNAME" = juwelsbooster ] \
       || [ "$SYSTEMNAME" = juwels ] \
       || [ "$SYSTEMNAME" = jurecadc ] \
       || [ "$SYSTEMNAME" = jusuf ]; then
    # Allow communication over InfiniBand cells on JSC machines.
    MASTER_ADDR="$MASTER_ADDR"i
fi
export MASTER_PORT=54123

# It's safest to hard-code this value because the number of array jobs
# may change (e.g., from resuming a part of array indices due to job
# failures).
export NUM_SHARDS="${NUM_SHARDS:-1}"
export SHARD_RANK="${SHARD_RANK:-${SLURM_ARRAY_TASK_ID:-0}}"

# Colon-separated list of JSON files to process. Set to empty
# string ('') if not desired.
# export INPUT_DATA_FILES="$root_scratch_dir"/"$project_name"/example-data/tiny-c4-100k.jsonl
export INPUT_DATA_FILES="${INPUT_DATA_FILES:-}"
# Glob-expression of JSON files to process. Set to empty string ('')
# if not desired.
export INPUT_DATA_FILES_GLOB="${INPUT_DATA_FILES_GLOB:-'/p/data1/trustllmd/ebert1/Nemotron-CC-HQ/*.jsonl'}"
# export INPUT_DATA_FILES_GLOB=''

export INPUT_FORMAT="${INPUT_FORMAT:-json}"

export OUTPUT_DATA_PARENT_DIR="${OUTPUT_DATA_PARENT_DIR:-${data_dir}/nemotron-cc-quality-high-actual-actual}"
export OUTPUT_DATA_SPLIT="${OUTPUT_DATA_SPLIT:-train}"
export OUTPUT_DATA_DIR="${OUTPUT_DATA_DIR:-${OUTPUT_DATA_PARENT_DIR}/${OUTPUT_DATA_SPLIT}-shuffled_shard-${SHARD_RANK}-of-${NUM_SHARDS}_${SLURM_JOB_NUM_NODES}-nodes}"
# export OUTPUT_DATA_DIR="$data_dir"/my-tiny-c4-t5-small-tok/val

export OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
export OUTPUT_COMPRESSION="${OUTPUT_COMPRESSION:-none}"

export MY_SPARK_CACHE_DIR="${MY_SPARK_CACHE_DIR:-$cache_dir}"

# Clean up previous jobs
# Declare global array to populate with `add_files_to_delete`.
files_to_delete=()
add_files_to_delete() {
    # Get all files of jobs that finished running (i.e., not in
    # `squeue`) and add them to the `files_to_delete` array.

    if [ "${#files_to_delete[@]}" -eq 0 ]; then
        echo "Need to manually reset \`files_to_delete\` before" \
             "calling \`add_files_to_delete\`."
        return 1
    fi

    unfinished_job_ids="$(squeue --me --array --format="%A" | tail -n +2 | sort | uniq)"
    # Take last fields, splitting by "-", to obtain job IDs of Spark cache
    # directories.
    spark_job_ids="$(find "$MY_SPARK_CACHE_DIR" -name '*spark*' -printf '%P\n' | awk 'BEGIN { FS="-"; } { print $NF; }' | sort | uniq)"

    while IFS='' read -r spark_job_id || [ -n "$spark_job_id" ]; do
        job_is_unfinished=0
        while IFS='' read -r unfinished_job_id || [ -n "$unfinished_job_id" ]; do
            if [ "$unfinished_job_id" = "$spark_job_id" ]; then
                job_is_unfinished=1
                break
            fi
        done < <(printf '%s' "$unfinished_job_ids")

        if [ "$job_is_unfinished" -eq 0 ]; then
            files_to_delete+=( "$spark_job_id" )
        fi
    done < <(printf '%s' "$spark_job_ids")
    return 0
}

add_files_to_delete
echo "before cleanup: $(date --iso-8601=seconds)"
[ "${#files_to_delete[@]}" -gt 0 ] && srun bash "$(get_curr_dir)"/clean_up_spark.sh "${files_to_delete[*]@Q}"
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

files_to_delete=()
add_files_to_delete
echo "before cleanup: $(date --iso-8601=seconds)"
[ "${#files_to_delete[@]}" -gt 0 ] && srun bash "$(get_curr_dir)"/clean_up_spark.sh "${files_to_delete[*]@Q}"
echo "after cleanup: $(date --iso-8601=seconds)"

pop_curr_file
