#!/usr/bin/env bash

# In this script, we set up our Python virtual environment, installing
# the repositories specified in the `repos` variable in
# `configuration.sh`.
#
# If the first argument is "download", the remaining arguments will be
# passed as extra arguments to `pip download`. These can be used, for
# example, to specify the `--platform` or `--python-version` to
# download for.
#
# If the first argument is given as "offline", pre-downloaded packages
# are installed.
#
# If the first argument is given as "update", repository states will
# be updated before each repository's re-installation. The repository
# update may fail, in which case individual Git conflicts have to be
# resolved manually and the script restarted.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../parent_env.sh
if [ "$#" -gt 1 ] && [ "$1" = __inherit__ ]; then
    # If we are inheriting from this environment, we use the parent of
    # this environment for further propagation, but all other
    # locations use the child environment.
    pop_curr_file

    _curr_file="$2"
    _curr_dir="$(dirname "$_curr_file")"
    source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"
    _args=( "${@:3}" )
else
    _args=( "$@" )
fi

if (("${DEBUG_TRUSTLLM_ENVS:-0}")); then
    printf '  in: %s\n    curr_file = %s\n' \
           "${BASH_SOURCE[0]:-${(%):-%x}}" \
           "$(get_curr_file)"
fi

# -----

# Re-use parent environment's script.
source "$parent_env_dir"/container-scripts/set_up_container.sh \
       __inherit__ "$(get_curr_file)" \
       "${_args[@]}"

pop_curr_file
