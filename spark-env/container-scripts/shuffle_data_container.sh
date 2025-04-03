#!/usr/bin/env bash

# Start a conversion from Parquet data in multiple files to shuffled
# Parquet data in a single file.

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

mkdir -p "$(dirname "$OUTPUT_DATA_DIR")"

export SPARK_LOCAL_DIRS="$cache_dir"/spark-"$SLURM_JOB_ID"
if ((NODE_RANK)); then
    spark_work_dir="$cache_dir"/spark-"$NODE_RANK"-"$SLURM_JOB_ID"
    spark-class org.apache.spark.deploy.worker.Worker \
                spark://"$MASTER_ADDR":"$MASTER_PORT" \
                --memory "$MAX_TOTAL_MEM_GB"G \
                --work-dir "$spark_work_dir"
else
    spark-class org.apache.spark.deploy.master.Master \
                --host "$MASTER_ADDR" --port "$MASTER_PORT" &
    master_proc="$!"

    python -u "$(get_curr_dir)"/../py-scripts/shuffle_data.py \
           --dist-input-files="$INPUT_DATA_FILES" \
           --dist-input-files-glob="$INPUT_DATA_FILES_GLOB" \
           --output-dir="$OUTPUT_DATA_DIR" \
           --local-dir "$SPARK_LOCAL_DIRS" \
           --event-dir "$cache_dir"/spark-events-"$SLURM_JOB_ID" \
           --max-total-mem-gb "$MAX_TOTAL_MEM_GB"

    kill -s INT "$master_proc"
fi
