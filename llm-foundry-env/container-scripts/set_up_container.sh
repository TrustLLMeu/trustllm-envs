#!/usr/bin/env bash

# In this script, we set up our Python virtual environment, installing
# the repositories specified in the `repos` variable in
# `configuration.sh`.
#
# If the first argument is "download", the remaining arguments will be
# passed as extra arguments to `pip download`. These can be used, for
# example, to specify the `--platform` or `--python-version` to
# download for.

set -euo pipefail

# Do not use these variables; they may be overwritten. Instead, use
# `get_curr_file` or `get_curr_dir` after sourcing `get_curr_file.sh`.
_curr_file="${BASH_SOURCE[0]:-${(%):-%x}}"
_curr_dir="$(dirname "$_curr_file")"
source "$_curr_dir"/../../global-scripts/get_curr_file.sh "$_curr_file"

source "$(get_curr_dir)"/../container-scripts/activate_container.sh setup

mkdir -p "$project_dir"
mkdir -p "$scratch_dir"

# Restore original files so patching works cleanly.
bash "$(get_curr_dir)"/restore_patch_backups.sh

if [ "$#" -gt 0 ] && [ "$1" = download ]; then
    mkdir -p "$pip_offline_dir"

    _is_installing=0
    _is_offline=0
    _pip_install_args=( download -d "$pip_offline_dir" "${@:2}" )
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
    _pip_install_args=( install --no-build-isolation --no-index --find-links 'file://'"$pip_offline_dir" )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
    _pip_install_unisolated_args=( "${_pip_install_args[@]}" )
else
    _is_installing=1
    _is_offline=0
    _pip_install_args=( install )
    _pip_install_upgrade_args=( "${_pip_install_args[@]}" -U )
    _pip_install_editable_args=( "${_pip_install_args[@]}" -e )
    _pip_install_unisolated_args=( "${_pip_install_args[@]}" --no-build-isolation )
fi

# Create or activate the Python virtual environment
if ! [ -d "$venv_dir" ]; then
    python -m venv --system-site-packages "$venv_dir"
    source "$venv_dir"/bin/activate
    python -m pip "${_pip_install_upgrade_args[@]}" pip
else
    source "$venv_dir"/bin/activate
    if ((_is_installing)) && ((_is_offline)); then
        python -m pip "${_pip_install_upgrade_args[@]}" pip
    fi
fi

# Clone and install the external repositories
mkdir -p "$ext_repo_dir"

# Install STK, ignoring dependencies, because it messes with Triton.
# Version taken from `megablocks/setup.py`.
python -m pip "${_pip_install_args[@]}" --no-deps 'stanford-stk==0.7.1'
# Install grouped GEMM, because it messes with the ARM container.
# Version taken from `llm-foundry/setup.py`.
python -m pip "${_pip_install_unisolated_args[@]}" 'grouped_gemm==0.1.6'

if [ "$(command -v nvcc)" ]; then
    _cuda_ver="$(nvcc --version | awk 'match($0, / release [0-9.]+,/) { prefix_len=length(" release "); print substr($0, RSTART + prefix_len, RLENGTH - prefix_len - 1); }')"
    _cuda_major_ver="$(echo "$_cuda_ver" | cut -d . -f 1)"
    _cuda_minor_ver="$(echo "$_cuda_ver" | cut -d . -f 2)"

    # The used FlashAttention-3 version requires CUDA ≥12.3.
    _install_fa3=0
    if [ "$_cuda_major_ver" -gt 12 ]; then
        _install_fa3=1
    elif [ "$_cuda_major_ver" -eq 12 ] && [ "$_cuda_minor_ver" -ge 3 ]; then
        _install_fa3=1
    fi

    # Install FlashAttention-3 according to TransformerEngine
    # version 1.11 installation instructions.
    # This version is the last one that matches the used TransformerEngine
    # version's installation instructions.
    if ((_install_fa3)); then
        # Handle installation failing.
        ! python -m pip "${_pip_install_args[@]}" 'git+https://github.com/Dao-AILab/flash-attention.git@v2.7.2#egg=flashattn-hopper&subdirectory=hopper'
        _python_site_dir="$(python -c 'import site; print(site.getsitepackages()[0])')"
        # If installation was successful, then execute further
        # installation instructions.
        if [ -f "$_python_site_dir"/flash_attn_interface.py ]; then
            mkdir -p "$_python_site_dir"/flashattn_hopper
            cp "$_python_site_dir"/flash_attn_interface.py "$_python_site_dir"/flashattn_hopper
        fi
    fi
fi

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

        # Do we maybe have to change the repo's remote URI?
        if [ "$_repo_uri" = 'https://github.com/TrustLLMeu/llm-foundry.git' ] \
               || [ "$_repo_uri" = 'https://github.com/TrustLLMeu/composer.git' ] \
               || [ "$_repo_uri" = 'https://github.com/TrustLLMeu/streaming.git' ] \
               || [ "$_repo_uri" = 'https://github.com/TrustLLMeu/megablocks.git' ]; then
            _forked_repo_uri=1
        else
            _forked_repo_uri=0
        fi
        # For safety, we upgrade URI of `origin` to our fork.
        # Previously this was the upstream MosaicML `origin`.
        if ((_forked_repo_uri)) \
           && [ "$(git remote get-url origin)" != "$_repo_uri" ]; then
            git remote add prev-origin "$(git remote get-url origin)"
            git remote set-url origin "$_repo_uri"
            git remote update
        fi

        if [ "$#" -gt 0 ] && [ "$1" = update ]; then
            git fetch --tags -f

            # Check whether we have something to stash: (We have to do
            # it so awkwardly so that Bash does not exit unsuccessful
            # commands.)
            # Check for staged changes.
            ! git diff-index --quiet --cached HEAD --
            _is_clean="$?"
            # Check for unstaged changes.
            ! git diff-files --quiet
            _is_clean="$((_is_clean && $?))"

            if ! ((_is_clean)); then
                git stash push -m "Update setup at $(date)"
            fi
            git checkout "$_repo_commit"
            if ! ((_is_clean)); then
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
