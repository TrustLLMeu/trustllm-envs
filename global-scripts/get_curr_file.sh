#!/usr/bin/env bash

# Save the current file at the top of a stack and make it available
# for peeking. When a script sources this file, it should also call
# `pop_curr_file` wherever it finishes execution.

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Need current file as single argument for \`get_curr_file.sh\`."
    exit 1
fi

# Define the stack variable if it doesn't exist.
_curr_files="${_curr_files:-}"

pop_curr_file() {
    _curr_files="$(echo "$_curr_files" | cut -d ':' -f 2-)"
    if [ "$_curr_files" = ':' ]; then
        _curr_files=''
    fi
}

get_curr_file() {
    echo "$_curr_files" | cut -d ':' -f 1
}

get_curr_dir() {
    dirname "$(get_curr_file)"
}

_curr_files="$1":"$_curr_files"
