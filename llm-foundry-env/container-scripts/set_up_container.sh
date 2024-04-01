#!/usr/bin/env bash

# In this script, we set up our Python virtual environment, installing
# the repositories specified in the `repos` variable in
# `configuration.sh`.

set -euo pipefail

_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../container-scripts/activate_container.sh setup

if ! [ -d "$venv_dir" ]; then
    python -m venv --system-site-packages "$venv_dir"
    source "$venv_dir"/bin/activate
    python -m pip install -U pip
else
    source "$venv_dir"/bin/activate
fi

mkdir -p "$(dirname "$repo_dir")"
for _repo_uri in "${!repos[@]}"; do
    # Take last part of URI, stripping ".git" at the end if it exists.
    _curr_repo_dir="$(basename "$_repo_uri" .git)"
    if ! [ -d "$_curr_repo_dir" ]; then
        git clone "$_repo_uri" "$_curr_repo_dir"
    fi
    cd "$_curr_repo_dir"
    # We do not pull so that software state is completely under user
    # control.

    _repo_pip_install_features="${repos["$_repo_uri"]}"
    python -m pip install -e ."$_repo_pip_install_features"
done

sed 's|libs = subprocess\..*$|libs = "/usr/local/cuda/lib64/stubs/libcuda.so"|g' /usr/lib/python3/dist-packages/triton/common/build.py > "$scratch_dir"/triton-build-patch.py
