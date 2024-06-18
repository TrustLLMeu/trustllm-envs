#!/usr/bin/env bash

# In this script, we set up our Python virtual environment, installing
# the repositories specified in the `repos` variable in
# `configuration.sh`.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../container-scripts/activate_container.sh setup

# Create the patched Triton file.
sed 's|libs = subprocess\..*$|libs = "/usr/local/cuda/lib64/stubs/libcuda.so"|g' /usr/lib/python3/dist-packages/triton/common/build.py > "$scratch_dir"/triton-build-patch.py

_pip_offline_dir="$scratch_dir"/pip-offline

if [ "$#" -gt 0 ] && [ "$1" = download ]; then
    _pip_install_args=( download -d "$_pip_offline_dir" )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" )
elif [ "$#" -gt 0 ] && [ "$1" = offline ]; then
    _pip_install_args=( install --no-index --find-links file://"$_pip_offline_dir" )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
else
    _pip_install_args=( install )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" -U )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
fi

# Create or activate the Python virtual environment
if ! [ -d "$venv_dir" ]; then
    python -m venv --system-site-packages "$venv_dir"
    source "$venv_dir"/bin/activate
    python -m pip "${_pip_install_upgrade_args[@]}" pip
else
    source "$venv_dir"/bin/activate
fi

# Clone and install the external repositories
mkdir -p "$(dirname "$ext_repo_dir")"
for _repo_tuple in "${repos[@]}"; do
    _repo_uri="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 1)"
    _repo_commit="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 2)"
    _repo_pip_install_features="$(echo "$_repo_tuple" | tr -s ' ' | cut -d ' ' -f 3)"

    # Take last part of URI, stripping ".git" at the end if it exists.
    _curr_repo_dir="$ext_repo_dir"/"$(basename "$_repo_uri" .git)"
    if ! [ -d "$_curr_repo_dir" ]; then
        git clone "$_repo_uri" "$_curr_repo_dir"
        pushd "$_curr_repo_dir"
        git checkout "$_repo_commit"
    else
        # By default, we do not check out when the repo already exists
        # so that software state is completely under user control.
        pushd "$_curr_repo_dir"
        if [ "$#" -gt 0 ] && [ "$1" = update ]; then
            # Check whether we have something to stash:
            # Check for staged changes.
            git diff-index --quiet --cached HEAD --
            _is_dirty="$?"
            # Check for unstaged changes.
            git diff-files --quiet
            _is_dirty="$((_is_dirty + $?))"

            git fetch --tags -f
            if ((_is_dirty)); then
                git stash push -m "Update setup at $(date)"
            fi
            git checkout "$_repo_commit"
            if ((_is_dirty)); then
                # The reason we do all of the above is that we want
                # this command to be able to fail, so that updating
                # stops when a user needs to resolve conflicts.
                git stash pop
            fi
        fi
    fi
    # We do not pull so that software state is completely under user
    # control.

    python -m pip "${_pip_install_editable_args[@]}" ."$_repo_pip_install_features"
    popd
done

pop_curr_file
