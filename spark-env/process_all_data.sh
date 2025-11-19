#!/usr/bin/env bash

# Process a directory containing (arbitrarily nested) directories of
# datasets.
#
# This will match a glob pattern and find all directories containing
# these blobs, then schedule a Slurm script on them via `sbatch` with
# the required amount of nodes, sharding and Slurm arrays.

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"

# JUSUF
# machine_name=jsf
# machine_partition='batch'
# ram_per_node_gb=256
# max_num_nodes=64
# JURECA DC
machine_name=jrc
machine_partition='dc-cpu'
ram_per_node_gb=256
max_num_nodes=128

account=trustllm-eu

preprocess_data_script="$curr_dir"/jsc/shuffle_data_general_"$machine_name".sbatch

# Default `spark.driver.maxResultSize` is set to `0.24 *
# ram_per_node_gb`, therefore this value.
required_memory_factor=0.24

input_root_data_dir=/p/data1/trustllmd/WP2/data_v2
input_data_format_glob='*.parquet'
input_data_format='parquet'
trustllm_envs_data_dir=/p/scratch/trustllm-eu/ebert1/spark/data
# output_data_root_dir="$trustllm_envs_data_dir"
output_data_root_dir=/p/data1/trustllmd/ebert1/data_v2
output_data_format='json'
output_data_compression='none'
# my_spark_cache_dir=/p/scratch/trustllm-eu/ebert1/spark/.cache
my_spark_cache_dir=/p/data1/trustllmd/ebert1/spark/.cache

# Whether to only print information and not start jobs.
print_only=1
# How many dataset entries to skip before continuing.
num_datasets_offset=0
# How many dataset entries to execute in total. Empty string to execute all.
num_datasets_jobs=''

i=0
while IFS='' read -r line || [ -n "$line" ]; do
    if [ "$i" -lt "$num_datasets_offset" ]; then
        i="$((i + 1))"
        continue
    fi
    if [ -n "$num_datasets_jobs" ] && [ "$i" -ge "$((num_datasets_jobs + num_datasets_offset))" ]; then
        break
    fi
    line="$(echo "$line" | tr '\t' ' ' | tr -s ' ')"
    size_byte="$(echo "$line" | cut -d ' ' -f 1)"
    data_dir="$(echo "$line" | cut -d ' ' -f 2)"
    # TODO
    # Strip common prefix (as specified by `input_root_data_dir` and a
    # single forward slash).
    data_dir_unique_tail="${data_dir##"$input_root_data_dir"/}"

    # TODO Maybe need to divide `required_memory_factor` further by 2.
    num_total_shards="$(python -c 'import math, sys; print(math.ceil(float(sys.argv[1]) / (float(sys.argv[2]) * (1024**3) * float(sys.argv[3]))))' "$size_byte" "$ram_per_node_gb" "$required_memory_factor")"
    if [ "$num_total_shards" -gt "$max_num_nodes" ]; then
        num_nodes="$max_num_nodes"
        num_shards="$(python -c 'import math, sys; print(math.ceil(float(sys.argv[1]) / float(sys.argv[2])))' "$num_total_shards" "$num_nodes")"
    else
        num_nodes="$num_total_shards"
        num_shards=1
    fi

    printf 'dir: %s\n  size: %s\n  num nodes: %s\n  num shards: %s\n  index: %s\n' \
           "$data_dir" "$size_byte" "$num_nodes" "$num_shards" "$i"
    if [ "$print_only" -eq 0 ]; then
        env AVAILABLE_MEM_GM="$ram_per_node_gb" \
            NUM_SHARDS="$num_shards" \
            INPUT_DATA_FILES_GLOB="$data_dir"/"$input_data_format_glob" \
            INPUT_FORMAT="$input_data_format" \
            OUTPUT_DATA_PARENT_DIR="$output_data_root_dir"/"$data_dir_unique_tail" \
            OUTPUT_FORMAT="$output_data_format" \
            OUTPUT_COMPRESSION="$output_data_compression" \
            MY_SPARK_CACHE_DIR="$my_spark_cache_dir" \
            bash "$curr_dir"/../submit_job.sh \
            --machine "$machine_name" \
            --nodes "$num_nodes" \
            --account "$account" \
            --array "0-$((num_shards - 1))%1" \
            --partition "$machine_partition" \
            "$preprocess_data_script"
    fi
    i="$((i + 1))"
done < <(find "$input_root_data_dir" -type f -name "$input_data_format_glob" -printf '%h\n' | sort | uniq | grep -v tdm_not_checked | xargs du -s -b | sort -n)
