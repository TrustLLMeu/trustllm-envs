#!/usr/bin/env bash

# Set up variables for `pip install` commands and related logic.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
if [ "$#" -gt 1 ] && [ "$1" = __inherit__ ]; then
    _curr_file="$2"
    _args=( "${@:3}" )
else
    _curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
    _args=( "$@" )
fi
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

if (("${DEBUG_TRUSTLLM_ENVS:-0}")); then
    printf '  in: %s\n    curr_file = %s\n' \
           "${BASH_SOURCE[0]:-${(%):-%x}}" \
           "$(get_curr_file)"
fi

# -----

source "$(get_curr_dir)"/../configuration.sh

if [ "$#" -gt 0 ] && [ "$1" = download ]; then
    mkdir -p "$pip_offline_dir"

    _is_installing=0
    _is_offline=0
    _pip_install_args=(
        download
        --cache-dir "$pip_cache_dir"
        -d "$pip_offline_dir"
        "${@:2}"
    )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" )
    _pip_install_unisolated_args=( "${_pip_install_args[@]}" )
elif [ "$#" -gt 0 ] && [ "$1" = offline ]; then
    if ! [ -d "$pip_offline_dir" ]; then
        echo "\`pip\` packages have not been pre-downloaded for offline" \
             "installation. Please place them at \`$pip_offline_dir\`."
    fi

    _is_installing=1
    _is_offline=1
    _pip_install_args=(
        install
        --cache-dir "$pip_cache_dir"
        --no-build-isolation
        --no-index
        --find-links 'file://'"$pip_offline_dir"
    )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
    _pip_install_unisolated_args=( "${_pip_install_args[@]}" )
else
    _is_installing=1
    _is_offline=0
    _pip_install_args=( install --cache-dir "$pip_cache_dir" )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" -U )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
    _pip_install_unisolated_args=(
        "${_pip_install_args[@]}"
        --no-build-isolation
    )
fi

pop_curr_file
