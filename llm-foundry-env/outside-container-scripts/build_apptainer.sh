#!/usr/bin/env bash

# Build the Apptainer container.

set -euo pipefail

curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
curr_dir="$(dirname "$curr_file")"
source "$curr_dir"/../outside-container-scripts/activate.sh

source "$curr_dir"/../../configure_apptainer.sh

apptainer pull "$container_file" "$container_uri"
