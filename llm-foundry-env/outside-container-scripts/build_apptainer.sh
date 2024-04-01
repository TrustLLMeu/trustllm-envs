#!/usr/bin/env bash

# Build the Apptainer container.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../outside-container-scripts/activate.sh

source "$_curr_dir"/../../configure_apptainer.sh

apptainer pull "$container_file" "$container_uri"
