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

_prev_args=( "${_args[@]}" )
_next_script="$(get_curr_dir)"/activate_container.sh
source "$_next_script" \
       __inherit__ "$_next_script" \
       setup
_args=( "${_prev_args[@]}" )

mkdir -p "$project_dir"
mkdir -p "$scratch_dir"

# Restore original files so patching works cleanly.
_prev_args=( "${_args[@]}" )
_next_script="$(get_curr_dir)"/restore_patch_backups.sh
source "$_next_script" \
       __inherit__ "$_next_script"
_args=( "${_prev_args[@]}" )

# Create patches if necessary.
_next_script="$(get_curr_dir)"/create_patches.sh
if [ -f "$_next_script" ]; then
    _prev_args=( "${_args[@]}" )
    source "$_next_script" \
           __inherit__ "$_next_script"
    _args=( "${_prev_args[@]}" )
fi

_prev_args=( "${_args[@]}" )
_next_script="$(get_curr_dir)"/configure_pip_install_variables.sh
source "$_next_script" \
       __inherit__ "$_next_script" \
       "${_args[@]}"
_args=( "${_prev_args[@]}" )

# Create or activate the Python virtual environment
if ! [ -d "$venv_dir" ]; then
    python3 -m venv --system-site-packages --without-pip "$venv_dir"
    source "$venv_dir"/bin/activate
    # Try to install `pip` in case it's not available. This command is
    # free to fail, as we may not have the `ensurepip` module, but
    # `pip` already.
    if ! ((_is_offline)); then
        ! python -m ensurepip --upgrade
    fi
    python -m pip "${_pip_install_upgrade_args[@]}" pip
else
    source "$venv_dir"/bin/activate
    if ((_is_installing)) && ((_is_offline)); then
        python -m pip "${_pip_install_upgrade_args[@]}" pip
    fi
fi

# Clone and install the external repositories
mkdir -p "$ext_repo_dir"

# Take set-up steps before installing external repositories.
_next_script="$(get_curr_dir)"/before_repos_steps.sh
if [ -f "$_next_script" ]; then
    _prev_args=( "${_args[@]}" )
    source "$_next_script" \
           __inherit__ "$_next_script" \
           "${_args[@]}"
    _args=( "${_prev_args[@]}" )
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
        _is_forked_repo_uri=0
        for _forked_repo_uri in "${forked_repo_uris[@]}"; do
            if [ "$_repo_uri" = "$_forked_repo_uri" ]; then
                _is_forked_repo_uri=1
                break
            fi
        done
        # For safety, we upgrade URI of `origin` to our fork.
        # Previously this was the upstream `origin`.
        if ((_is_forked_repo_uri)) \
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

    # Optionally install individual repositories in a specific way.
    _next_script="$(get_curr_dir)"/install_repo.sh
    if [ -f "$_next_script" ]; then
        _prev_args=( "${_args[@]}" )
        source "$_next_script" \
               __inherit__ "$_next_script" \
               "$_repo_uri" \
               "$_repo_commit" \
               "$_repo_pip_install_features" \
               "${_args[@]}"
        _args=( "${_prev_args[@]}" )
    else
        python -m pip "${_pip_install_editable_args[@]}" ."$_repo_pip_install_features"
    fi
    popd
done

# Take set-up steps after installing external repositories.
_next_script="$(get_curr_dir)"/after_repos_steps.sh
if [ -f "$_next_script" ]; then
    _prev_args=( "${_args[@]}" )
    source "$_next_script" \
           __inherit__ "$_next_script" \
           "${_args[@]}"
    _args=( "${_prev_args[@]}" )
fi

pop_curr_file
