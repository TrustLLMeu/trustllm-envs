#!/usr/bin/env bash

# Take set-up steps after external repositories have been installed.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/configure_pip_install_variables.sh

# Install EuroEval.
python -m pip "${_pip_install_args[@]}" 'euroeval[all]'

# Install torchrun_jsc to fix distributed job launching.
python -m pip "${_pip_install_args[@]}" 'torchrun_jsc>=0.0.17'

pop_curr_file
